---
title: "A State Machine Built on a Static Procedure Table"
date: 2026-07-19
draft: true
tags: ["Fortran", "procedure pointers", "state machines"]
---

In the [previous post]({{< ref "20260719_static-procedure-tables.md" >}}) we
saw that Fortran 2008 allows a *named constant* to hold procedure pointers —
a static dispatch table, fixed at compile time. A table of procedures indexed
by an integer is begging to be used for something, and the classic something
is a **finite state machine**: let the integer be the current state, and let
the procedure compute the next one.

## Recognizing a real literal

Our example task comes from compiler construction: decide whether a string
is a valid real literal such as `3.14159` or `.279`. This is the textbook
job of a *deterministic finite automaton* (DFA), and I have borrowed the
automaton from page 4 of [Charles N. Fischer's CS 536 lecture
notes](https://pages.cs.wisc.edu/~fischer/cs536.s06/lectures/Lecture07.4up.pdf)
(Prof. Emeritus of Computer Science, University of Wisconsin–Madison). The
notes define a FORTRAN-like real literal — which requires digits on either
or both sides of a decimal point, or just a string of digits — by the
regular expression

```text
RealLit = (D+ (λ | . )) | (D* . D+)
```

where `D` is a digit and `λ` is the empty string. So `42.0`, `31.`, `.279`,
and even the bare digit string `987654321` are all valid, while `.`, `ABC`,
and the empty string are not.

The corresponding machine has four states, plus `0` serving as the error
state:

| State | Meaning                              | Transitions                       | Accepting? |
|-------|--------------------------------------|-----------------------------------|------------|
| 1     | start                                | `.` → 2, digit → 3, otherwise → 0 | no         |
| 2     | seen leading dot, need a digit       | digit → 4, otherwise → 0          | no         |
| 3     | reading digits before the dot        | digit → 3, `.` → 4, otherwise → 0 | yes        |
| 4     | reading digits after the dot         | digit → 4, otherwise → 0          | yes        |

A string is accepted if, after consuming every character, the machine sits
in one of the *final* states 3 or 4 — state 3 covers `D+` (with the
optional trailing dot moving us to 4), and state 4 covers everything that
ends in digits after a decimal point.

Each state becomes an ordinary function taking the current character and
returning the next state. The state machine driver then reduces to a
three-line loop: look up the current state in the table, call the procedure,
repeat until the string ends or we fall into the error state.

## The program

```fortran
! state_machine.f90 - Example of a state machine using procedure dispatch
!
! The state machine implements a deterministic finite automaton
! for determining if a string is a valid real literal.
!
! As of Nov 2025, only flang and NAG support the static dispatch table.
!

module dfa_real_literal
implicit none

! The finite automaton is borrowed from page 4 of the pdf
! https://pages.cs.wisc.edu/~fischer/cs536.s06/lectures/Lecture07.4up.pdf

contains

! State 1
function leading_dot_or_digit(d) result(s)
    character(len=1), intent(in) :: d
    integer :: s
    if (d == '.') then
        s = 2
    else if (index('0123456789',d) > 0) then
        s = 3
    else
        s = 0
    end if
end function

! State 2
function digit_after_leading_dot(d) result(s)
    character(len=1), intent(in) :: d
    integer :: s
    if (index('0123456789',d) > 0) then
        s = 4
    else
        ! not a valid digit
        s = 0
    end if
end function

! State 3
function digit_after_leading_digit(d) result(s)
    character(len=1), intent(in) :: d
    integer :: s
    if (index('0123456789',d) > 0) then
        s = 3
    else if (d == '.') then
        s = 4
    else
        s = 0
    end if
end function

! State 4
function digit_after_trailing_digit(d) result(s)
    character(len=1), intent(in) :: d
    integer :: s
    if (index('0123456789',d) > 0) then
        s = 4
    else
        s = 0
    end if
end function

end module

program state_machine

use dfa_real_literal
implicit none

type :: state
    procedure(leading_dot_or_digit), pointer, nopass :: p => null()
end type

! Static dispatch table
type(state), parameter :: table(4) = [&
    state(leading_dot_or_digit),&
    state(digit_after_leading_dot),&
    state(digit_after_leading_digit),&
    state(digit_after_trailing_digit)]

! Accepting (final) states of the automaton
logical, parameter :: accepting(4) = [.false.,.false.,.true.,.true.]

print *, is_real_literal("42.0")
print *, is_real_literal("3.14159")
print *, is_real_literal(".279")
print *, is_real_literal("31.")
print *, is_real_literal("ABC")
print *, is_real_literal("987654321")
print *, is_real_literal(".")

contains

    logical function is_real_literal(str)
        character(len=*), intent(in) :: str ! Must be left-adjusted on entry
        integer :: i, s
        s = 1
        do i = 1, len_trim(str)
            s = table(s)%p(str(i:i))
            if (s == 0) exit
        end do
        is_real_literal = s > 0
        if (is_real_literal) is_real_literal = accepting(s)
    end function

end program
```

Compiling and running with flang:

```text
$ flang state_machine.f90 && ./a.out
 T
 T
 T
 T
 F
 T
 F
```

`42.0`, `3.14159`, `.279`, and `31.` are accepted; so is `987654321`,
which is a valid `RealLit` by Fischer's definition (the `D+` branch).
`ABC` dies immediately — `A` is neither a dot nor a digit, so state 1
sends it straight to the error state — and a lone `.` ends in state 2,
which is not a final state.

## The dispatch-table driver

The heart of the program is this loop:

```fortran
s = 1
do i = 1, len_trim(str)
    s = table(s)%p(str(i:i))
    if (s == 0) exit
end do
```

The current state `s` indexes into the constant `table`, whose element
carries the procedure pointer for that state; calling it with the next
character yields the new state. The driver knows nothing about the
automaton — add states and transition functions, extend the table, and the
loop is untouched. The accepting states are data too, a constant logical
array indexed by state, so the acceptance test at the end is just a lookup.

Because `table` is a `parameter`, there is no set-up code to run before
first use; the table is part of the program's read-only data, just like a
`static const` array of function pointers in C. And since every element is
known at compile time, a sufficiently clever optimizer is free to
devirtualize the calls — `table(s)%p` can only ever be one of four known
procedures.

## A portable workaround

As discussed in the previous post, the static table is the one ingredient
compilers still struggle with: as of November 2025, only **NAG Fortran**
and recent **flang** accept the `parameter` declaration with procedure
targets in the structure constructors. Until the other compilers catch up,
the same machine can be driven by a plain `do` loop with a `select case`
inside:

```fortran
s = 1
do i = 1, len_trim(str)
    select case (s)
    case (1)
        s = leading_dot_or_digit(str(i:i))
    case (2)
        s = digit_after_leading_dot(str(i:i))
    case (3)
        s = digit_after_leading_digit(str(i:i))
    case (4)
        s = digit_after_trailing_digit(str(i:i))
    end select
    if (s == 0) exit
end do
```

This compiles everywhere, needs no procedure pointers at all, and a good
compiler turns it into the same kind of indexed jump the dispatch table
produces. (Our forebears would have written it as a computed `GO TO`,
`goto (1,2,3,4) s` — a jump table in statement form, obsolescent since
Fortran 95, of which `select case` is the modern descendant.) The
difference is one of organization rather than speed: with `select case`
the dispatch lives in *control flow*, hard-wired into the driver, whereas
the procedure table moves it into *data* — the driver stays fixed while
the table can be sized, extended, or swapped wholesale.

If you would rather keep the table organization on a compiler without the
F2008 feature, the fallback from the previous post applies as well: fill
an ordinary `save`d variable at start-up instead of declaring a constant.

## Closing thoughts

A DFA driver is about the smallest useful program you can hang off a
dispatch table, but the pattern scales: interpreters, event handlers,
protocol parsers — anywhere the question "what do I do next?" is answered
by an integer. With Fortran 2008's constant procedure tables the answer
can be wired in at compile time.
