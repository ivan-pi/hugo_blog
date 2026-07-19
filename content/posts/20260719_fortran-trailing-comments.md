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

The more interesting question is what to do about continuation lines.

### Can't we just work line by line?

My initial hope was that the stripper could process each line in isolation,
with no memory between lines. Interestingly, statement continuation *by itself*
does not ruin that hope. If every string literal opens and closes on the same
physical line, the scanner starts and ends every line in the "outside" state,
so the lines can be judged independently — even lines that continue a
statement:

```fortran
call assemble(stiffness, &   ! comments after & are fine
              loads)         ! (outside character context)
```

The one construct that defeats line-by-line processing is a *continued
character context*, i.e. a string literal split across lines:

```fortran
print *, "this string spans &
     &two lines! see?"  ! trailing comment
```

The second line begins in the middle of a string literal, but nothing *on that
line* tells you so — the evidence sits at the end of the previous line. A
stateless scanner starts the second line in the "outside" state, takes the `!`
after `lines` for a comment, and shreds the code:

```fortran
program demo
    print *, "this string spans &
         &two lines
end program
```

```
split_bad.f90:2:15:

    2 |     print *, "this string spans &
      |               1
Error: Unterminated character constant beginning at (1)
```

The version that carries its state across calls strips only the real comment
and leaves a compilable program behind:

```fortran
program demo
    print *, "this string spans &
         &two lines! see?"
end program
```

So the necessary amount of memory between lines is exactly one item: *did the
previous line end inside a string, and if so, with which delimiter* — the same
three states as before. That is the entire price of handling continuations.
Conversely, if you are willing to impose a style rule that literals are never
split across lines (concatenate with `//` instead — kinder to `grep` users
anyway), then the stateless line-by-line stripper really is sufficient.

The quick-and-dirty way to carry the state is a `save` attribute, with the
understanding that the caller feeds the function one line at a time, in
order. While I was at it, I changed the result from a logical to
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

## How long is a line, anyway?

Before assembling the full stripper, one more pitfall. My first draft read
each line into a `character(len=80) :: line` buffer, which silently truncates
anything longer — a bug waiting to happen in a tool that rewrites source
files. What is a
safe length? The standards keep moving the goalposts: free-form lines were
limited to 132 characters from Fortran 90 through 2018, but **Fortran 2023
raised the limit to 10,000 characters per line**, and to one million characters
per statement (replacing the older cap of 255 continuation lines from
Fortran 2003). Compilers have long accepted over-long lines as an extension
anyway.

One clean option is to declare `character(len=10000)` and lean on the standard:
for conforming F2023 source that is now a guaranteed upper bound. The nicer
option is to not guess at all and grow the buffer while reading, using a
non-advancing `read` in a loop:

```fortran
!> Read a complete record, growing the buffer as needed
subroutine get_line(unit, line, iostat)
    integer, intent(in) :: unit
    character(len=:), allocatable, intent(out) :: line
    integer, intent(out) :: iostat
    character(len=256) :: chunk
    integer :: sz
    line = ""
    do
        read (unit, '(a)', advance='no', size=sz, iostat=iostat) chunk
        if (sz > 0) line = line // chunk(1:sz)
        if (iostat == iostat_eor) then
            iostat = 0      ! end of record: line is complete
            return
        end if
        if (iostat /= 0) return   ! end of file or error
    end do
end subroutine
```

A non-advancing read fills the chunk without consuming the record terminator;
when it hits the end of the record it signals `iostat_eor` (from
`iso_fortran_env`) and reports the number of characters actually transferred in
`sz`. The [Fortran stdlib](https://stdlib.fortran-lang.org/page/specs/stdlib_io.html)
offers a ready-made `getline` with the same idea. Note that
`has_trailing_comment` itself never cared: it takes assumed-length
`character(len=*)`, so only the driver needed fixing. (In this light, my
100-element delimiter stack — which after the nesting fix can never hold more
than one entry — remains generously dimensioned.)

## The stripper, eating its own source

Here is the complete program: read lines from standard input, drop full-line
comments, truncate trailing ones, and echo the rest.

```fortran
! strip_demo.f90 -- demonstrate detection of Fortran trailing comments
program strip_demo
    use, intrinsic :: iso_fortran_env, only: input_unit, iostat_eor
    implicit none

    character(len=:), allocatable :: line
    integer :: pos, iostat

    do
        call get_line(input_unit, line, iostat)
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

    ! ... get_line, comment_or_blank, and has_trailing_comment from above ...

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

## What about fixed form?

In some respects fixed form is the *easier* target. Comment lines are
recognized by column position alone — `C` or `*` in column 1 in FORTRAN 77,
with `!` joining them in Fortran 90 — and lines effectively end at column 72,
with columns 73–80 reserved for sequence numbers (a comment zone of sorts).

Trailing comments, however, are a younger invention than one might think:
standard FORTRAN 77 had *no* inline comments at all. The `!` trailing comment
entered the standard with Fortran 90, in both source forms, after years as a
popular vendor extension (VAX FORTRAN being the usual culprit to credit).
Nowadays fixed-form code freely mixes `C` comment lines with `!` trailing
comments.

For a stripping tool, fixed form needs the same three-state lexer with a few
column-based tweaks: truncate at column 72 first; treat a `!` in column 6 as a
continuation marker rather than a comment (any character other than blank or
`0` in column 6 continues the previous line); and note that character context
can still be split across lines, so the cross-line string state is just as
necessary as in free form. The one genuine horror is the Hollerith-style `H`
edit descriptor — `FORMAT(1H!)` embeds an unquoted, uncounted-by-our-lexer
exclamation mark. It was declared obsolescent in Fortran 90 and deleted in
Fortran 95, but legacy code is exactly where fixed form lives.

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
- **Preprocessor directives** (`#define` and friends) have their own quoting
  rules.

If you can construct a well-formed free-form line (or sequence of lines) that
fools the function, I'd love to hear about it.
