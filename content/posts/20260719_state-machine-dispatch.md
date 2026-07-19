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

The corresponding machine has four states, plus an error state:

| State          | Meaning                          | Transitions                       | Accepting? |
|----------------|----------------------------------|-----------------------------------|------------|
| `start`        | nothing seen yet                 | `.` → `leading_dot`, digit → `integer_part`, otherwise → `err` | no |
| `leading_dot`  | seen `.`, a digit must follow    | digit → `fraction`, otherwise → `err` | no |
| `integer_part` | reading digits before the dot    | digit → `integer_part`, `.` → `fraction`, otherwise → `err` | yes |
| `fraction`     | seen a dot with digits around it | digit → `fraction`, otherwise → `err` | yes |

A string is accepted if, after consuming every character, the machine sits
in one of the *final* states — `integer_part` covers the `D+` branch (with
the optional trailing dot moving us to `fraction`), and `fraction` covers
everything else.

Each state gets an ordinary function, `from_<state>`, taking the current
character and returning the next state. The state machine driver then
reduces to a three-line loop: look up the current state in the table, call
the procedure, repeat until the string ends or we fall into the error
state.

## The program

```fortran
! real_literal.f90 - Recognizing real literals with a state machine
!
! The finite automaton is borrowed from page 4 of the pdf
! https://pages.cs.wisc.edu/~fischer/cs536.s06/lectures/Lecture07.4up.pdf
!
! As of Nov 2025, only flang and NAG support the static dispatch table.
!

module real_literals
implicit none
private
public :: is_real_literal

! States of the automaton
integer, parameter :: err          = 0  ! not a real literal
integer, parameter :: start        = 1  ! nothing seen yet
integer, parameter :: leading_dot  = 2  ! seen '.', a digit must follow
integer, parameter :: integer_part = 3  ! reading digits before the dot
integer, parameter :: fraction     = 4  ! seen a dot with digits around it

contains

    ! Transition functions, one per state; each maps the
    ! current character c to the next state.

    function from_start(c) result(next)
        character(len=1), intent(in) :: c
        integer :: next
        if (c == '.') then
            next = leading_dot
        else if (is_digit(c)) then
            next = integer_part
        else
            next = err
        end if
    end function

    function from_leading_dot(c) result(next)
        character(len=1), intent(in) :: c
        integer :: next
        if (is_digit(c)) then
            next = fraction
        else
            next = err
        end if
    end function

    function from_integer_part(c) result(next)
        character(len=1), intent(in) :: c
        integer :: next
        if (is_digit(c)) then
            next = integer_part
        else if (c == '.') then
            next = fraction
        else
            next = err
        end if
    end function

    function from_fraction(c) result(next)
        character(len=1), intent(in) :: c
        integer :: next
        if (is_digit(c)) then
            next = fraction
        else
            next = err
        end if
    end function

    logical function is_digit(c)
        character(len=1), intent(in) :: c
        is_digit = index('0123456789', c) > 0
    end function

    logical function is_real_literal(str)
        character(len=*), intent(in) :: str ! Must be left-adjusted on entry

        type :: transition
            procedure(from_start), pointer, nopass :: next => null()
        end type

        ! Static dispatch table, one row per state
        type(transition), parameter :: table(4) = [ &
            transition(from_start), &
            transition(from_leading_dot), &
            transition(from_integer_part), &
            transition(from_fraction)]

        ! Accepting (final) states of the automaton
        logical, parameter :: accepting(0:4) = &
            [.false., .false., .false., .true., .true.]

        integer :: i, s

        s = start
        do i = 1, len_trim(str)
            s = table(s)%next(str(i:i))
            if (s == err) exit
        end do
        is_real_literal = accepting(s)
    end function

end module

program test_real_literals
use real_literals, only: is_real_literal
implicit none
print *, is_real_literal("42.0")
print *, is_real_literal("3.14159")
print *, is_real_literal(".279")
print *, is_real_literal("31.")
print *, is_real_literal("ABC")
print *, is_real_literal("987654321")
print *, is_real_literal(".")
end program
```

Compiling and running with flang:

```text
$ flang real_literal.f90 && ./a.out
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
`ABC` dies immediately — `A` is neither a dot nor a digit, so `from_start`
sends it straight to the error state — and a lone `.` ends in
`leading_dot`, which is not a final state.

## The dispatch-table driver

The heart of the program is this loop:

```fortran
s = start
do i = 1, len_trim(str)
    s = table(s)%next(str(i:i))
    if (s == err) exit
end do
is_real_literal = accepting(s)
```

The current state `s` indexes into the constant `table`, whose `transition`
element carries the procedure pointer for that state; calling it with the
next character yields the new state — `table(s)%next(c)` reads almost like
the textbook notation *δ(s, c)* for a DFA's transition function. The
driver knows nothing about the automaton: add states and transition
functions, extend the table, and the loop is untouched. The accepting
states are data too — a constant logical array indexed by state, with the
error state included at index 0 so that the acceptance test at the end is
a single lookup whatever way the loop ends.

Note where everything is declared. The `transition` type, the table, and
the `accepting` mask live *inside* `is_real_literal` — Fortran allows type
definitions and named constants local to a procedure, so the machinery of
the automaton can sit exactly where it is used, invisible to the rest of
the module. The module itself exports one thing: `is_real_literal`. And
because `table` is a `parameter`, there is no set-up code to run before
first use; the table is part of the program's read-only data, just like a
`static const` array of function pointers in C. Since every element is
known at compile time, a sufficiently clever optimizer is free to
devirtualize the calls — `table(s)%next` can only ever be one of four
known procedures.

## A portable workaround

As discussed in the previous post, the static table is the one ingredient
compilers still struggle with: as of November 2025, only **NAG Fortran**
and recent **flang** accept the `parameter` declaration with procedure
targets in the structure constructors. Until the other compilers catch up,
the same machine can be driven by a plain `do` loop with a `select case`
inside:

```fortran
s = start
do i = 1, len_trim(str)
    select case (s)
    case (start)
        s = from_start(str(i:i))
    case (leading_dot)
        s = from_leading_dot(str(i:i))
    case (integer_part)
        s = from_integer_part(str(i:i))
    case (fraction)
        s = from_fraction(str(i:i))
    end select
    if (s == err) exit
end do
is_real_literal = accepting(s)
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
