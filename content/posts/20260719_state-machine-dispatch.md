---
title: "A State Machine Built on a Static Procedure Table"
date: 2026-07-19
draft: true
tags: ["Fortran", "procedure pointers", "state machines", "goto"]
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
(Prof. Emeritus of Computer Science, University of Wisconsin–Madison).

The machine has four states, plus `0` serving as the error state:

| State | Meaning                              | Transitions                          |
|-------|--------------------------------------|--------------------------------------|
| 1     | start                                | `.` → 2, otherwise → 3               |
| 2     | seen leading dot, need a digit       | digit → 4, otherwise → 0             |
| 3     | reading digits before the dot        | digit → 3, `.` → 4, otherwise → 0    |
| 4     | reading digits after the dot         | digit → 4, otherwise → 0             |

Each state becomes an ordinary function taking the current character and
returning the next state. The state machine driver then reduces to a
three-line loop: look up the current state in the table, call the procedure,
repeat until the string ends or we fall into the error state.

## The program

For fun, the program implements the driver loop twice — once with the
static dispatch table, and once the way our forebears would have written it:
with a **computed `GO TO`**. A preprocessor flag selects between them:

```fortran
! state_machine.F90 - Example of a state machine using procedure dispatch
!
! The state machine implements a deterministic finite automaton
! for determining if a string is a valid real literal.
!
! To compile use:
!
!   flang -DTABLE=<.true.|.false.> state_machine.F90
!
! Two implementation variants are available
! - procedure dispatch table
! - computed GOTO
!
! As of Nov 2025, only flang and NAG support the dispatch table.
!

! Implementation switch
#ifndef TABLE
#define TABLE .true.
#endif

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
    else
        s = 3
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

#ifdef TABLE
type :: state
    procedure(leading_dot_or_digit), pointer, nopass :: p => null()
end type

type(state), parameter :: table(4) = [&
    state(leading_dot_or_digit),&
    state(digit_after_leading_dot),&
    state(digit_after_leading_digit),&
    state(digit_after_trailing_digit)]
print *, "Using TABLE is ", TABLE
#endif

print *, is_real_literal("42.0")
print *, is_real_literal("3.14159")
print *, is_real_literal(".279")
print *, is_real_literal("31.")
print *, is_real_literal("ABC")
print *, is_real_literal("987654321")

contains

    logical function is_real_literal(str)
        character(len=*), intent(in) :: str ! Must be left-adjusted on entry
        integer :: i, s, NXT
        s = 1

! We use a Fortran if block, to make sure both variants are in a valid state
if (TABLE) then

        do i = 1, len_trim(str)
            s = table(s)%p(str(i:i))
            if (s == 0) exit
        end do
        is_real_literal = s > 0

else

        i = 1
        s = 1
    110 if (i > len_trim(str)) goto 120
        goto (1,2,3,4) s
120     is_real_literal = s > 0
        return
      1 s = leading_dot_or_digit(str(i:i))
        goto 100
      2 s = digit_after_leading_dot(str(i:i))
        goto 100
      3 s = digit_after_leading_digit(str(i:i))
        goto 100
      4 s = digit_after_trailing_digit(str(i:i))
    100 i = i + 1
        go to 110

end if
    end function

end program
```

Compiling and running the dispatch-table variant:

```text
$ flang -DTABLE=.true. state_machine.F90 && ./a.out
 Using TABLE is  T
 T
 T
 T
 T
 F
 T
```

`42.0`, `3.14159`, `.279`, and `31.` are all accepted, and `ABC` is
rejected — the `B` arrives while the machine is in state 3 and knocks it
into the error state. (The final `T` for `987654321` deserves a comment;
see below.)

## The dispatch-table driver

The heart of the table variant is this loop:

```fortran
do i = 1, len_trim(str)
    s = table(s)%p(str(i:i))
    if (s == 0) exit
end do
is_real_literal = s > 0
```

The current state `s` indexes into the constant `table`, whose element
carries the procedure pointer for that state; calling it with the next
character yields the new state. The driver knows nothing about the
automaton — add states and transition functions, extend the table, and the
loop is untouched. Because `table` is a `parameter`, there is no set-up
code to run before first use; the table is part of the program's read-only
data, just like a `static const` array of function pointers in C.

One simplification worth flagging: the acceptance test `s > 0` treats
*every* non-error state as accepting. That is why `987654321` — which
never sees a decimal point and ends in state 3 — is reported as valid,
and a lone `"."` (ending in state 2) would be too. A stricter recognizer
would accept only in designated final states, e.g.
`is_real_literal = s == 4`. I have kept the loose test to keep the driver
minimal; tightening it is a one-line exercise for the reader.

## The computed `GO TO` driver

Before procedure pointers (Fortran 2003) and even before derived types
(Fortran 90), state machines in Fortran were driven by the **computed
`GO TO`**:

```fortran
goto (1,2,3,4) s
```

This jumps to label `1`, `2`, `3`, or `4` depending on whether `s` is 1, 2,
3, or 4 — a jump table in statement form, and a direct ancestor of C's
`switch`. Each labelled statement calls the corresponding transition
function, then control flows back around to the top of the (label-built)
loop. It works, and a good compiler turns it into the same kind of indexed
jump the dispatch table produces — but the control flow is invisible to the
reader, held together by bare integer labels. The computed `GO TO` has been
declared **obsolescent** since Fortran 95, with `select case` as the usual
modern replacement. The dispatch table is another: it moves the jump table
from control flow into *data*, where it can be sized, extended, or even
swapped wholesale.

A remark on the plumbing: the choice between the two variants is a plain
Fortran `if (TABLE) then` on a preprocessor-defined logical constant, not an
`#ifdef` around the whole driver. This is deliberate — both variants are
compiled and syntax-checked in every build, and since `TABLE` is a
compile-time constant, the dead branch is trivially eliminated by the
optimizer. (The `.F90` extension, with a capital `F`, is the conventional
signal that a file must pass through the preprocessor first.)

## Compiler support

As in the previous post, the limiting factor is the static table itself:
as of November 2025, only **NAG Fortran** and recent **flang** accept the
`parameter` declaration with procedure targets in the structure
constructors. On other compilers you can fall back to filling an ordinary
`save`d variable at start-up — or, in the spirit of this post's second
half, a computed `GO TO`.

## Closing thoughts

A DFA driver is about the smallest useful program you can hang off a
dispatch table, but the pattern scales: interpreters, event handlers,
protocol parsers — anywhere the question "what do I do next?" is answered
by an integer. With Fortran 2008's constant procedure tables the answer can
be wired in at compile time, and the sixty-year-old computed `GO TO` can
finally retire.
