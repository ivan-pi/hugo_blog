---
title: "A Dark Corner of Fortran: Optional Passed-Object Dummy Arguments"
date: 2026-07-19
draft: true
tags: ["Fortran", "OOP", "dark-corners"]
---

I recently stumbled upon a new dark corner of the Fortran language — or perhaps
better said, of Fortran compilers. The question that started it all:

> Can we use an *optional* passed-object dummy argument before the dynamic type
> of a polymorphic entity has been established?

Consider the following program:

```fortran
module m
 type :: foo
 contains
  procedure, pass, non_overridable :: check
 end type
contains
 subroutine check(f)
  class(foo), optional :: f
  if (present(f)) then
   print *, "present"
  else
   print *, "not present"
  end if
 end subroutine
end module

use m
type(foo), allocatable :: f
class(foo), allocatable :: g

call f%check
allocate(f)
call f%check

call g%check
allocate(foo :: g)
call g%check
end
```

The type-bound procedure `check` takes the passed object as an `optional`
dummy argument. Since Fortran 2008, passing an unallocated allocatable (or a
disassociated pointer) actual argument to an optional dummy is a perfectly
legitimate way of signalling absence — `present(f)` then evaluates `.false.`.
So one might expect the program to print:

```text
not present
present
not present
present
```

And indeed, with some compilers it happily does. But is it actually legal?

## The compilers stay silent

My first instinct was to ask the compilers. When compiled with

```text
gfortran -Og -fcheck=pointer
```

which according to the [manual](https://gcc.gnu.org/onlinedocs/gfortran/Code-Gen-Options.html)
should "enable generation of run-time checks for pointers and allocatables",
I get no error reported. The NAG compiler with `-C=pointer` also doesn't
complain. (I sent a ticket to NAG, and Malcolm Cohen promised they would fix
it — more on his reply below.)

## The verdict from NAG

Malcolm Cohen replied quickly. In short: **it is illegal to invoke a
type-bound procedure of an unallocated or unassociated variable**, no matter
what the interface of the procedure looks like. Quoting his reply:

> Your program violates the requirement in paragraph 2 of 15.5.1 Syntax of a
> procedure reference, which states:
>
> "The data-ref in a procedure-designator shall not be an unallocated
> allocatable variable or a pointer that is not associated."

This makes both `call f%check` and `call g%check` (before the `allocate`
statements) invalid.

Note where the restriction lives: it constrains the *procedure designator*
`f%check` itself, before argument association even enters the picture. The
familiar optional-argument semantics — unallocated actual, absent dummy —
never get a chance to apply, because the reference is already non-conforming
at the point of the call. The extra requirement on the data-ref overrules the
default optional semantics.

## Can we have both `pass` and `optional`?

Interestingly, the combination itself seems to be allowed. The standard
does not appear to rule out declaring the passed-object dummy argument as
`optional`. The constraint on the passed-object dummy argument (C761 in
Fortran 2018) requires it to be a scalar, polymorphic (for an extensible
type), non-pointer, non-allocatable dummy data object — but says nothing
about `optional`. It's just that there is no conforming way to
actually *omit* it in a type-bound call: the syntax `f%check` always
designates `f` as the passed object, and `f` must be a valid (allocated,
associated) object for the reference to be legal in the first place.

## A variation with a pointer

Gilbert Brietzke sent me a variation that probes the same corner through a
pointer, alongside a plain-old-data type for contrast:

```fortran
module m
 type bar
     integer :: i=1
 end type
 type :: foo
 contains
  procedure, pass, non_overridable :: check
 end type
contains
 subroutine check(f)
  class(foo), optional :: f
  if (present(f)) then
   print *, "present"
  else
   print *, "not present"
  end if
 end subroutine
end module

program test
use m
type(foo), allocatable, target :: f
type(bar), allocatable :: p
class(foo), pointer :: g

print*, p
allocate(p)
print*, p
g=>f
call f%check
call g%check
allocate(f)
g=>f
call f%check
call g%check

end program
```

(The `print*, p` of the unallocated `p` is of course its own little sin —
referencing an unallocated variable — but it illustrates how easily these
things slip through.)

Initially I thought this should work, because the optional argument semantics
in Fortran allow passing an allocatable or pointer variable, and if the
variable is not allocated or associated, `present()` evaluates `.false.`.
But in the case of a type-bound call the data-ref requirement from 15.5.1
takes precedence. The `non_overridable` attribute doesn't buy us an
exemption either: even though the compiler could in principle resolve the
call statically without ever looking at the dynamic type, the standard makes
no such carve-out.

## What about C++?

The situation reminded me of static member functions in C++. Is one allowed
to call a static member function through an "unformed" pointer?

```cxx
class A {
public:
    static int a(int i);
};

int main() {

   A *a;

   // Is this legal?
   a->a(42);

   // or is this better?
   a = new A();
   if (a) a->a(42);

}
```

Even though `A::a` is static and no object is needed to call it, the object
expression `a` in `a->a(42)` is still evaluated. Reading the value of an
uninitialized pointer is undefined behavior, so the first call is not legal —
the safe spelling is simply `A::a(42)`, which sidesteps the object expression
entirely. Fortran's type-bound call syntax offers no such escape hatch: the
passed object *is* the data-ref, and the data-ref must be valid. The closest
Fortran equivalent would be to call the module procedure directly,
`call check()`, but then we've given up the type-bound syntax altogether.

## Where the example came from

The origin of the program is a thread on Fortran Discourse:
[What is benefit of PASS in type-bound procedures?](https://fortran-lang.discourse.group/t/what-is-benefit-of-pass-in-type-bound-procedures/9294)

In that thread I was playing with the `pass(arg)` attribute, which lets the
passed object appear at an arbitrary position in the argument list:

```fortran
module engine_mod

type :: engine_type
contains
   procedure(ignite_fun), pass(engine) :: ignite
end type

contains
   subroutine ignite(params,engine)
      real :: params(3)
      class(engine_type) :: engine
      print *, "Igniting engine with params: ", params
   end subroutine
end module
```

The more interesting use case I was exploring is using an *optional*
passed-object dummy argument as a means of implementing a default fallback
method. Here is a sketch of a linear solver interface, where the Krylov
method object is the passed object, but the same procedure is also reachable
through a generic `linsolve` interface that can omit it:

```fortran
! linear_operators_demo.f90 --
!   Example of using passed-object dummy arguments as a means
!   of implementing a default fallback method.
!
!   This produces tight coupling of the problem class (linop) and the
!   solver class (krylov_method).
!
module linear_operators

implicit none
private

public :: dp, linop, matvec, preconditioner
public :: krylov_method, bicgstab
public :: linsolve

integer, parameter :: dp = kind(1.0d0)

! A linear operator of the form y = op(x)
type, abstract :: linop
    integer :: n = 0
contains
   procedure(apply_sub), deferred :: apply
end type

abstract interface
    subroutine apply_sub(op,x,y)
        import linop, dp
        class(linop), intent(in) :: op
        real(dp), intent(in) :: x(op%n)
        real(dp), intent(out) :: y(op%n)
    end subroutine
end interface

! Applies the y = A x operation, where A is a dense matrix
type, extends(linop) :: matvec
    ! Dense matrix, for the sake of this experiment
    real(dp), allocatable :: A(:,:)
contains
    procedure :: apply => apply_matvec

! N.b.: we could also make this method non_overridable
    procedure, pass(A) :: solve => solve_using_method
end type

! Applies the P = M^{-1} operation, by default this is just M = I
type, extends(linop) :: preconditioner
contains
    procedure :: apply => default_pc
end type

! Applies the A^{-1} operation, using a Krylov process
type, abstract :: krylov_method
contains
    procedure(solve_sub), deferred, pass(method) :: apply
end type

abstract interface
    subroutine solve_sub(A,b,x,P,method,info)
        import matvec, preconditioner, krylov_method, dp
        class(matvec), intent(in) :: A
        real(dp), intent(in) :: b(:)
        real(dp), intent(inout) :: x(:)
        class(preconditioner), intent(in), optional :: P
        class(krylov_method), intent(inout), optional :: method
        integer, intent(out) :: info
    end subroutine
end interface

! One particular Krylov method
type, extends(krylov_method) :: bicgstab
contains
    procedure, pass(method) :: apply => apply_bicgstab
end type

! Add to generic overload set, for solving different problems
interface linsolve
    module procedure :: solve_using_method
end interface

contains

    ! Dense matrix-vector product
    subroutine apply_matvec(op,x,y)
        class(matvec), intent(in) :: op
        real(dp), intent(in) :: x(op%n)
        real(dp), intent(out) :: y(op%n)
        y = matmul(op%A,x)
    end subroutine

    ! y = I x
    subroutine default_pc(op,x,y)
        class(preconditioner), intent(in) :: op
        real(dp), intent(in) :: x(op%n)
        real(dp), intent(out) :: y(op%n)
        y = x
    end subroutine

    subroutine apply_bicgstab(A,b,x,P,method,info)
        class(matvec), intent(in) :: A
        real(dp), intent(in) :: b(:)
        real(dp), intent(inout) :: x(:)
        class(preconditioner), intent(in), optional :: P
        class(bicgstab), intent(inout), optional :: method
        integer, intent(out) :: info

        ! this should always work in theory
        if (.not. present(method)) error stop "bicgstab method is not present."

        info = 0
        print *, "Calling fake bicgstab routine"

    end subroutine

    ! generic solve procedure with fallback to a default method
    subroutine solve_using_method(A,b,x,P,method,info)
        class(matvec), intent(in) :: A
        real(dp), intent(in) :: b(:)
        real(dp), intent(inout) :: x(:)
        class(preconditioner), intent(in), optional :: P
        class(krylov_method), intent(inout), optional :: method
        integer, intent(out) :: info
        if (present(method)) then
            call method%apply(A,b,x,P,info)
        else
            info = 0
            print *, "Calling fallback method"
        end if
    end subroutine

end module


program linear_operator_demo

    use linear_operators
    implicit none

    type(preconditioner) :: eye
    type(matvec) :: A
    class(krylov_method), allocatable :: method

    integer, parameter :: n = 3
    real(dp) :: x(n), b(n)
    integer :: info

    allocate( bicgstab :: method )

    call method%apply(A,b,x,info=info)
    call A%solve(b,x,method=method,info=info)
    call A%solve(b,x,info=info)

    call linsolve(A,b,x,P=eye,method=method,info=info)

end program
```

The idea was that a caller with a `method` object in hand could use the
type-bound syntax `method%apply(...)`, while a caller without one falls back
to `linsolve(A,b,x,info=info)`, and the implementation dispatches internally
via `present(method)`. This works — as long as `method` is actually allocated
whenever it appears as the data-ref of a type-bound call. The "unallocated
method means use the default" shortcut is exactly the illegal pattern
dissected above.

## Takeaways

- Declaring a passed-object dummy argument as `optional` appears to be
  standard-conforming — but there is no conforming way to invoke the
  type-bound procedure with the passed object absent.
- The data-ref in a type-bound procedure reference must not be an unallocated
  allocatable or a disassociated pointer (F2023, 15.5.1 para 2). This
  requirement kicks in *before* argument association, so the generous
  optional-argument semantics never apply.
- Current compilers (gfortran with `-fcheck=pointer`, NAG with `-C=pointer`)
  don't catch the violation at run time yet, so the program silently
  "works" — the worst kind of dark corner. NAG has promised a fix.

I have submitted the example to Peter Klausler's
[fortran-wringer-tests](https://github.com/klausler/fortran-wringer-tests/issues/12)
repository, which collects exactly these kinds of non-portable and
questionable-usage cases.

*Thanks to Malcolm Cohen (NAG) for the standard interpretation, and to
Gilbert Brietzke for the pointer variation of the example.*
