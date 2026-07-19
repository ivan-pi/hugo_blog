---
title: "Assigning to a Function Call: Pointer-Valued Functions in Fortran"
date: 2026-07-19
draft: true
tags: ["Fortran", "pointers"]
---

There is a little-known feature of Fortran involving functions that return
pointers. Since Fortran 2008, a reference to such a function may appear not
only in expressions, but also on the *left-hand side* of an assignment — and
in other so-called *variable definition contexts*. Here is just a little
taste of it:

```fortran
push(mystack) = 1
push(mystack) = 2
push(mystack) = 3
```

These may look like array element assignments, but they are actually
*function calls*. To see what is going on, let's build the example up piece
by piece. (The complete program is available as [stack.f90](stack.f90) if
you'd like to follow along at home.)

## A stack of integers

We start with a derived type holding a fixed-size buffer of 1000 integers
and a counter `i` pointing at the top of the stack. The components are
`private`, so client code can only manipulate the stack through the
procedures of the module:

```fortran
module stack_type
implicit none
public

type :: stack
    private
    integer :: i = 0
    integer :: a(1000)
end type

contains

    ! ... procedures shown below ...

end module
```

Thanks to default initialization, a freshly declared `stack` starts out
empty — no constructor call needed.

## Is it empty? Is it full?

Two small helper functions query the state of the stack. The counter tells
us everything we need to know:

```fortran
    logical function is_empty(s)
        type(stack), intent(in) :: s
        is_empty = s%i == 0
    end function

    logical function is_full(s)
        type(stack), intent(in) :: s
        is_full = s%i == 1000
    end function
```

Nothing surprising so far. These guard the operations that follow.

## Push and pop

Now for the interesting part. A conventional `push` would take the stack
*and* the value to be stored as arguments. Instead, our `push` takes only
the stack, reserves the next free slot, and returns a *pointer* to it:

```fortran
    function push(s) result(k)
        type(stack), intent(inout), target :: s
        integer, pointer :: k
        if (is_full(s)) error stop "Stack overflow"
        s%i = s%i + 1
        k => s%a(s%i)
    end function
```

The value itself never passes through `push`. It arrives later, through the
returned pointer — this is what will let us write `push(mystack) = 1`.

Its counterpart `pop` is an ordinary function returning the top value and
decrementing the counter:

```fortran
    function pop(s) result(k)
        type(stack), intent(inout) :: s
        integer :: k
        if (.not. is_empty(s)) then
            k = s%a(s%i)
            s%i = s%i - 1
        end if
    end function
```

(Popping an empty stack leaves the result undefined here; a real
implementation would want to handle that case more gracefully.)

## Putting the stack to use

With the module in place, the main program becomes delightfully short:

```fortran
program demo
use stack_type

type(stack), target :: mystack

push(mystack) = 1
push(mystack) = 2
push(mystack) = 3

do while (.not. is_empty(mystack))
    print *, pop(mystack)
end do

end program
```

Each call to `push` bumps the stack counter and returns a pointer to the
newly reserved slot; the assignment then stores the value through that
pointer. Compiling and running with gfortran 13.3:

```text
$ gfortran -std=f2018 -Wall stack.f90 && ./a.out
           3
           2
           1
```

## What the standard says

In Fortran 2008 the syntax rule for a variable was extended to (R602 in the
2008 standard, R902 in Fortran 2018):

```text
variable  is  designator
          or  function-reference
```

where the function reference is constrained to return a data pointer. In
other words, wherever a variable is expected, you may also write a reference
to a pointer-valued function, and the *target* of the returned pointer is the
variable being defined. Before Fortran 2008 you had to spell out the
temporary yourself:

```fortran
integer, pointer :: k
k => push(mystack)
k = 1
```

The one-liner `push(mystack) = 1` is exactly this, with the intermediate
pointer hidden from view.

The left-hand side of an assignment is only one of the variable definition
contexts. Another one that works today is passing the function reference as
an actual argument to an `intent(out)` or `intent(inout)` dummy:

```fortran
call set_to_seven(push(mystack))   ! defines the freshly pushed element
```

The standard also permits a pointer function reference as an input item in a
`read` statement,

```fortran
read(*,*) push(mystack)
```

although gfortran 13 does not accept this one yet ("Error: 'push' at (1) is
not a variable").

## Mind the target attribute

One subtlety is easy to overlook. Inside `push`, the dummy argument `s` has
the `target` attribute, and the result pointer is associated with a
subobject of it. The rules of argument association (Fortran 2018, 15.5.2.7)
say that if the *actual* argument does not also have the `target` attribute,
any pointers associated with the dummy become undefined when the function
returns — which is precisely the moment the assignment needs the pointer!
That is why the demo program declares

```fortran
type(stack), target :: mystack
```

The example happens to work with gfortran even without `target` on
`mystack`, but strictly speaking that program would not be standard
conforming.

## Towards a dictionary

Where this could get really fun is *associative* containers. A
pointer-valued lookup function makes it possible to write a dictionary whose
entries are created on first access, in the spirit of
`std::map::operator[]` in C++ — although I have never actually seen this
done in the wild, apart from the odd thread on the [Fortran
Discourse](https://fortran-lang.discourse.group/t/assignment-to-returned-pointer/1958).

As a proof of concept, here is a toy dictionary mapping strings to
integers (full program in [dict.f90](dict.f90)):

```fortran
type :: pair
    character(len=:), allocatable :: key
    integer :: val
end type

type :: dict
    private
    type(pair), allocatable :: pairs(:)
contains
    procedure :: of
end type
```

The lookup function scans the pairs for a matching key, appending a new
zero-initialized entry if the key is not found, and returns a pointer to the
value:

```fortran
    function of(self, key) result(v)
        class(dict), intent(inout), target :: self
        character(len=*), intent(in) :: key
        integer, pointer :: v
        integer :: i
        if (.not. allocated(self%pairs)) allocate(self%pairs(0))
        do i = 1, size(self%pairs)
            if (self%pairs(i)%key == key) then
                v => self%pairs(i)%val
                return
            end if
        end do
        self%pairs = [self%pairs, pair(key, 0)]
        v => self%pairs(size(self%pairs))%val
    end function
```

The same function then serves both sides of the assignment — on the left it
*defines* an entry, on the right the pointer result is dereferenced and the
value of its target is used:

```fortran
type(dict), target :: fruit

fruit%of("apples") = 3
fruit%of("oranges") = 5
fruit%of("apples") = fruit%of("apples") + 1

print *, fruit%of("apples"), fruit%of("oranges")   ! prints 4, 5
```

The client code is pleasant, but I'm not convinced the implementation is
the right way to go about it. The deferred-length `allocatable` keys mean
every key is a separate small heap allocation, and the array constructor
`[self%pairs, pair(key, 0)]` reallocates and copies the whole table on every
insertion. A serious dictionary would hash its keys into buckets and manage
the key storage more carefully. Still, as a demonstration of what
pointer-valued functions make *syntactically* possible, it serves its
purpose.

## Further reading

Reinhold Bader shows this type of usage in his course on [Advanced Fortran
Topics](https://doku.lrz.de/files/10746213/10746218/1/1684600341697/Advanced_Fortran_OO.pdf)
(slide 38).

I'd like to thank Gilbert Brietzke for discussion and feedback on the stack
example.
