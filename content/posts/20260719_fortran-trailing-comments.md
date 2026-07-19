---
title: "How Hard Can It Be to Strip Fortran Comments?"
date: 2026-07-19
draft: true
tags: ["Fortran"]
---

I recently wanted a small tool to strip comments from free-form Fortran source files.
Half of the job is trivial. If the first non-blank character of a line is an
exclamation mark, the whole line is a comment and we can drop it:

```fortran
logical function comment_or_blank(line)
    character(len=*), intent(in) :: line
    character(len=:), allocatable :: first
    first = adjustl(line)
    comment_or_blank = len_trim(first) == 0
    if (.not. comment_or_blank) comment_or_blank = first(1:1) == "!"
end function
```

The other half — *trailing* comments — turned out to be more interesting than
expected. Consider this specimen:

```fortran
i = scan("String contains exclamation!","!") ! Has a trailing comment too!
```

Scanning left to right for the first `!` (say, with `index(line,"!")`) fails,
because a string literal may contain exclamation marks. Scanning right to left
fails too, because the trailing comment itself may contain them. So neither end
of the line is safe to start from.

## A three-state machine

What we actually need is a (very) small lexer. Scanning left to right, we track
whether we are currently inside a string literal, and the first `!` encountered
*outside* of any string starts the trailing comment. Since Fortran has two
string delimiters, there are exactly three states: outside a string, inside a
`'...'` literal, and inside a `"..."` literal.

Two features of Fortran keep this machine small. First, string literals do not
nest — an apostrophe inside a double-quoted string is just a character, and vice
versa. Second, Fortran has no escape characters: a delimiter is embedded by
doubling it (`'it''s'`), not by escaping it (`'it\'s'`). No lookbehind needed.

If you were hoping for a regex: for a *single* line this language is in fact
regular, and something like

```
^([^!'"]|'[^']*'|"[^"]*")*!
```

matches exactly the lines with a trailing comment. (Doubled quotes come along
for free — `'it''s'` simply matches as two adjacent literals.) The catch is
that a statement, and even a string literal, can be *continued* across lines
with `&`, so a line-at-a-time regex has no way of knowing that the current line
starts in the middle of a string. That state has to live somewhere between
lines, and at that point a hand-rolled loop is simpler than a regex.

## The ChatGPT attempt

I asked ChatGPT for a first draft and got back a function built around a stack
of open delimiters:

```fortran
logical function has_trailing_comment(line)
    character(len=*), intent(in) :: line
    integer :: i, top
    character(len=1), dimension(100) :: stack

    ! Initialize the stack pointer
    top = 0

    ! Loop through each character in the line
    do i = 1, len_trim(line)
        select case (line(i:i))
            case ("'", '"')
                ! Toggle in and out of strings
                if (top > 0 .and. stack(top) == line(i:i)) then
                    ! End of current string
                    top = top - 1
                else
                    ! Start of new string
                    top = top + 1
                    stack(top) = line(i:i)
                end if

            case ("!")
                ! Detect exclamation mark only if we are outside any string
                if (top == 0) then
                    has_trailing_comment = .true.
                    return
                end if
        end select
    end do

    ! If we reach here, there was no exclamation outside a string
    has_trailing_comment = .false.
end function
```

It looks plausible, but it has two genuine bugs.

**Bug 1: Fortran does not short-circuit.** The condition

```fortran
if (top > 0 .and. stack(top) == line(i:i)) then
```

is written with C instincts, where `&&` guarantees the right operand is only
evaluated if the left one is true. Fortran makes no such promise — the standard
allows a processor to evaluate both operands of `.and.` in any order (or, for
that matter, to skip either one). With `top == 0`, the reference `stack(top)`
is out of bounds. gfortran happens to evaluate both operands, so the very first
quote character on a line trips the bounds checker:

```
$ gfortran -fcheck=bounds -o v1 v1.f90 && ./v1
At line 18 of file v1.f90
Fortran runtime error: Index '0' of dimension 1 of array 'stack' below lower bound of 1
```

At least this one is loud (with the right compiler flags).

**Bug 2: strings don't nest, but the stack thinks they do.** Any quote
character that doesn't match the top of the stack gets *pushed*, as if it
opened a nested string. Feed it

```fortran
print *, "don't"  ! oops
```

and the apostrophe in `don't` pushes a bogus `'` onto the stack. The closing
`"` no longer matches the top, so it gets pushed as well, and by the time we
reach the `!` the function believes we are three strings deep. Without bounds
checking, the function quietly returns `.false.` — no trailing comment found.

## A fix, plus continuation lines

Fixing the nesting logic is easy: while inside a string, a matching delimiter
pops, and any other quote character is simply ignored. (With that change the
stack can never hold more than one element, so it is really just a single
saved `mode` character wearing a disguise. I kept the stack as a memento of the
function's origin.)

The more interesting change is handling continuation lines. A string literal
may end with `&` and continue on the next line, which means the in-string state
has to survive *between* calls. The quick-and-dirty solution is a `save`
attribute, with the understanding that the caller feeds the function one line
at a time, in order. While I was at it, I changed the result from a logical to
an integer that returns the *position* of the `!`, so the caller can slice off
the comment with `line(1:pos-1)`:

```fortran
!> Test for a trailing comment
!
! Result:
!  >0 - position of the '!' starting the trailing comment
!   0 - no trailing comment
!  -1 - line ends in a continuation
!
impure integer function has_trailing_comment(line)
    character(len=*), intent(in) :: line

    ! The stack persists across function calls
    save :: top, stack

    character(len=1), dimension(100) :: stack
    integer :: i, top = 0

    do i = 1, len_trim(line) ! Loop through each character in the line
        select case (line(i:i))
        case ("'", '"')     ! Toggle in and out of strings
            if (top > 0) then
                if (stack(top) == line(i:i)) top = top - 1
            else
                ! Start of new string
                top = top + 1
                if (top > 100) error stop "Failed:&
! comment in midst of string, just for testing the "&" case
                                         & stack overflow."
                stack(top) = line(i:i)
            end if
        case ("!")  ! Detect exclamation mark only if we are outside any string
            if (top == 0) then
                has_trailing_comment = i
                return
            end if
        case ("&")
            if (verify(line(i+1:), ' ') == 0) then
                has_trailing_comment = -1
                return
            end if
        end select
    end do
    ! If we reach here, there was no exclamation outside a string
    has_trailing_comment = 0
end function
```

The `&` case fires only when the ampersand is the last non-blank character on
the line, which is what marks a continuation. The function is declared `impure`
because the saved state makes successive calls order-dependent — it could not
legally be `pure` anyway.

You may have noticed the function is written to test itself: it carries
trailing comments on purpose, and the `error stop` message is a string literal
continued across lines — with a full comment line wedged in the middle of the
character context. As far as I can tell this is standard-conforming (the free
form rules say the continuation resumes on the next *noncomment* line), and
gfortran accepts it without complaint. It also demonstrates why the
full-line-comment check must run *before* the trailing-comment lexer: the
embedded comment line contains both a `"` and a `&`, and would corrupt the
saved state if it were fed to the state machine.

## The stripper, eating its own source

Here is the complete program: read lines from standard input, drop full-line
comments, truncate trailing ones, and echo the rest.

```fortran
! strip_demo.f90 -- demonstrate detection of Fortran trailing comments
program strip_demo
    implicit none

    character(len=80) :: line
    integer :: pos, iostat

    do
        read (*, '(a)', iostat=iostat) line
        if (iostat /= 0) exit

        ! Full-line comments are easy: drop them entirely
        if (comment_or_blank(line)) cycle

        pos = has_trailing_comment(line)
        select case (pos)
        case (1:)
            write (*, '(a)') line(1:pos-1)   ! strip the comment
        case default
            write (*, '(a)') trim(line)      ! 0 or -1: keep as-is
        end select
    end do

contains

    ! ... comment_or_blank and has_trailing_comment from above ...

end program
```

The obvious test input is the program itself:

```
$ gfortran -Wall -fcheck=all -o strip_demo strip_demo.f90
$ ./strip_demo < strip_demo.f90 > stripped.f90
$ gfortran -o stripped stripped.f90 && echo OK
OK
```

The stripped source compiles, every comment is gone — including the comment
line embedded in the continued string — and the `error stop` message still
reads `"Failed: stack overflow."`. A few more lines through the wringer:

```
$ ./strip_demo << EOF
i = scan("String contains exclamation!","!") ! Has a trailing comment too!
print *, "don't"  ! oops
print *, 'it''s f_i_n_e!'
x = 1 + &
    2  ! rest of the sum
EOF
i = scan("String contains exclamation!","!")
print *, "don't"
print *, 'it''s f_i_n_e!'
x = 1 + &
    2
```

The `don't` line that silently defeated version 1 is now handled, and the `!`
inside `'it''s f_i_n_e!'` survives, since the doubled apostrophe toggles the
state out and immediately back in.

## Known gaps

The function only *approximately* recognizes trailing comments, under the
assumption that the input is well-formed free-form Fortran. If the source is
broken — say, an unterminated string — the misclassification is on the house.
Some gaps I am aware of:

- **The result codes aren't exhaustive.** A line like `x = 1 + &  ! note` both
  continues *and* carries a comment; the function reports the comment (which is
  what the stripper needs), not the continuation.
- **No reset.** The saved state persists across files; a proper tool would wrap
  the state in a derived type, or at least offer a reset.
- **`include` lines** pull in text the line stream never sees.
- **Fixed-form source** is a different game entirely: `C` or `*` in column 1,
  continuation in column 6, and Hollerith constants that embed unquoted
  exclamation marks.
- **Preprocessor directives** (`#define` and friends) have their own quoting
  rules.

And some trivia for perspective: Fortran 2003 capped a statement at 255
continuation lines; Fortran 2023 instead allows a statement of up to one
million characters. Either way, my 100-element delimiter stack — which can
never hold more than one entry — is dimensioned generously enough.

If you can construct a well-formed free-form line (or sequence of lines) that
fools the function, I'd love to hear about it.
