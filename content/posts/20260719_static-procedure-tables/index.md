---
title: "Static Procedure Tables in Fortran"
date: 2026-07-19
draft: true
tags: ["Fortran", "procedure pointers", "standard conformance"]
---

Dispatch tables — arrays mapping an index to a procedure — are a classic
technique for building interpreters, state machines, and plugin registries.
In C you would write a static array of function pointers and be done with it.
Modern Fortran can express the same idea with procedure pointer components,
and since Fortran 2008 the table can even be a *named constant*, fixed at
compile time. At least on paper: as of 2023, **every compiler I tried got
this wrong**. This post shows the feature, why it is valid, and the small
bug-reporting campaign that followed.

> 📎 The complete example is attached to this post:
> [`dispatch_test.f90`](dispatch_test.f90)

## Three functions and an interface

We need some procedures to dispatch to. Three toy functions will do, each
returning a single character, so that we can easily check which one was
called. They share the abstract interface `retchar`:

```fortran
module funcs
abstract interface
    function retchar()
       character(len=1) :: retchar
    end function
end interface
contains
    function a()
        character(len=1) :: a
        a = 'a'
    end function
    function b()
        character(len=1) :: b
        b = 'b'
    end function
    function c()
        character(len=1) :: c
        c = 'c'
    end function
end module
```

## A container for a procedure pointer

Fortran does not allow arrays of procedure pointers directly, so the usual
workaround is to wrap the pointer in a derived type — a "procedure
container" — and build an array of those:

```fortran
! Procedure container
type :: pc
    procedure(retchar), pointer, nopass :: rc => null()
end type
```

The `nopass` attribute matters: without it the component would be treated
as a type-bound procedure expecting the object itself as an argument.

## The table, two ways

The traditional way to fill a table is at run time, one structure
constructor per entry:

```fortran
! Dynamic dispatch table
function build_table() result(table)
    type(pc) :: table(3)
    table = [pc(a),pc(b),pc(c)]
end function
```

This works on every compiler and always has. But the table never changes —
so why build it at run time at all? Since Fortran 2008 the same structure
constructors may appear in the initializer of a *named constant*:

```fortran
! Static dispatch table
type(pc), parameter :: table(3) = [pc(a),pc(b),pc(c)]
```

Here the procedure names `a`, `b`, `c` appear as data sources in a
structure constructor that initializes a `parameter`. There is no run-time
construction step at all: the table is baked into the object file, like a
C `static` array of function pointers. For a big interpreter-style
dispatch table that is exactly what you want — no initialization order
concerns, no "did somebody call `build_table` yet?" bookkeeping, and the
constant can be used anywhere a module variable can.

## Exercising both tables

The test program calls each entry through both tables and concatenates the
results; if everything is wired up correctly, both spell `abc`:

```fortran
program test
    use dispatch_table, only: pc, build_table
    implicit none
    type(pc) :: table(3)
    table = build_table() ! Dynamic table
    associate(abc => &
        table(1)%rc()//table(2)%rc()//table(3)%rc())
        if (abc /= 'abc') stop 1
    end associate

    block
        use dispatch_table, only: table ! Static table
        associate(abc => &
            table(1)%rc()//table(2)%rc()//table(3)%rc())
            if (abc /= 'abc') stop 2
        end associate
    end block

    print *, 'PASS'
end program
```

(The `block` construct with its own `use` statement lets the static
`table` shadow the local variable of the same name.)

The attached file [`dispatch_test.f90`](dispatch_test.f90) assembles these
pieces into a complete program — the two table variants live side by side
in a module `dispatch_table`. On a compiler that supports the static
table:

```text
$ flang dispatch_test.f90 && ./a.out
 PASS
```

## But is it legal?

Yes — although the relevant rules take some assembling. In the Fortran 2023
draft ([J3/24-007](https://j3-fortran.org/doc/year/24/24-007.pdf), §7.5.10),
the syntax rule for structure constructors reads:

> R758 *component-data-source* is *expr* or *data-target* or *proc-target*

When I raised the question on the Intel Fortran forum, [Steve
Lionel](https://stevelionel.com/drfortran/) — retired Intel Fortran developer
and ISO Fortran Committee convenor — [spelled out the
chain](https://community.intel.com/t5/Intel-Fortran-Compiler/Procedure-target-in-structure-constructor/m-p/1680983#M175458):

> My take is that this is valid usage, though it does not astonish me that
> compilers get this wrong. Here's my logic:
>
> R758 allows a *proc-target* as a *component-data-source*.
> C7109 says "a *proc-target* shall correspond to a procedure pointer
> component.", which it does here.
> R1041 says that *proc-target* can be a *procedure-name*
> C1033 includes a module procedure in the list of allowed uses of a
> *proc-target* here

Moreover, the rules for *constant expressions* (§10.1.12) — which is what
the initializer of a named constant must be — explicitly allow a structure
constructor whose pointer components are initial targets, such as the name
of a module procedure. So the static table above is standard-conforming
Fortran, and has been since Fortran 2008.

## The state of the compilers

Valid or not, when I tested this in late 2023 no compiler accepted it:
gfortran, flang, ifx, and LFortran all rejected the declaration or crashed on
it, and even NAG needed a fix. [Reinhold
Bader](https://fortran-lang.discourse.group/t/in-memoriam-reinhold-bader/7591)
first reported the problem to NAG, and I filed reports with the other
vendors:

- flang: [llvm-project issue #72058](https://github.com/llvm/llvm-project/issues/72058)
- GCC: [PR 117070](https://gcc.gnu.org/bugzilla/show_bug.cgi?id=117070#c1)
- Intel Fortran: [forum thread](https://community.intel.com/t5/Intel-Fortran-Compiler/Procedure-target-in-structure-constructor/m-p/1680983#M175458)
- LFortran: [issue #2848](https://github.com/lfortran/lfortran/issues/2848)

The situation has since improved: NAG Fortran 7.2 and recent flang releases
compile the program above and print `PASS`. It is a nice reminder that
niche-feature bug reports do get acted on — a fifteen-year-old corner of the
standard went from universally broken to working in two compilers, simply
because somebody wrote it down.

## A recursive curiosity

Once constants can hold procedure pointers, you can construct some pretty
interesting (read: strange) programs. Here is a *constant* whose component
points at a procedure that calls itself *through the constant* — with the
implementation hidden in a submodule so that the module can name the
procedure before its body exists:

```fortran
module recursive_callback
implicit none
private

public :: my_f

abstract interface
    recursive subroutine ffunc(i)
      integer, intent(in) :: i
    end subroutine
end interface

interface
   recursive module subroutine a(i)
      integer, intent(in) :: i
   end subroutine
end interface

type :: callback
    procedure(ffunc), pointer, nopass :: f
end type

type(callback), parameter :: my_f = callback(a)

end module

submodule (recursive_callback) impl
contains
module procedure a
  print *, i
  if (i < 1) return
  call my_f%f(i-1)  ! same as `call a(i)`
end procedure
end submodule

program test
use recursive_callback, only: my_f
call my_f%f(5)    ! same as call a(5)
end program
```

> 📎 Also attached: [`recursive_callback.f90`](recursive_callback.f90)

The recursion never touches the procedure name directly — each level goes
back through the parameter `my_f`. NAG Fortran 7.2 handles it without
complaint:

```text
> nagfor recursive_callback.f90
NAG Fortran Compiler Release 7.2(Shin-Urayasu) Build 7203
[NAG Fortran Compiler normal termination]
> ./a.out
 5
 4
 3
 2
 1
 0
```

as does the new flang. I would not recommend structuring production code this
way, but it is a satisfying stress test: the compiler must resolve a module
procedure interface into a constant before the procedure's definition has
even been seen.

## Closing thoughts

If you have wanted C-style static function pointer tables in Fortran, the
language has had them since 2008 — the compilers just needed a nudge. Check
whether your compiler of choice handles the attached examples, and if it
does not, file a bug. It worked for me.

## Acknowledgments

I would like to thank Reinhold Bader and Gilbert Brietzke for friendly
discussions on this topic.
