---
title: "Pascal's Triangle at Compile Time in Fortran"
date: 2026-07-18
draft: false
tags: ["Fortran", "compile-time", "metaprogramming"]
katex: true
---

Pascal's triangle — also known as **Khayyam's triangle** after the Persian
mathematician and poet Omar Khayyam — arranges the binomial coefficients

{{< neq 1 "\binom{n}{k} = \frac{n!}{k!\,(n-k)!}" >}}

into a triangular grid. Each interior entry is the sum of the two entries above
it. It is a lovely little object, and it turns out we can build the whole thing
*at compile time* in modern Fortran, so that the running program does nothing
but print a table of literals.

Here is the complete program:

```fortran
! pascal.f90 -- prints Pascal's triangle
implicit none
integer, parameter :: nmax = 8
character(len=*), parameter :: fmt = '(9(I6,:,1X))'   ! 9 = nmax + 1
integer, parameter :: pascal(0:nmax, 0:nmax) = reshape( &
    [([( product([(i, integer :: i = n-k+1, n)])  &
       / product([(i, integer :: i = 1, k)]),     &
       integer :: k = 0, nmax)], integer :: n = 0, nmax)], [nmax+1, nmax+1])
write(*,fmt) pascal
end
```

Compiling and running it with [flang](https://flang.llvm.org/docs/) 22.1.8:

```text
$ flang -pedantic pascal.f90 && ./a.out
     1      0      0      0      0      0      0      0      0
     1      1      0      0      0      0      0      0      0
     1      2      1      0      0      0      0      0      0
     1      3      3      1      0      0      0      0      0
     1      4      6      4      1      0      0      0      0
     1      5     10     10      5      1      0      0      0
     1      6     15     20     15      6      1      0      0
     1      7     21     35     35     21      7      1      0
     1      8     28     56     70     56     28      8      1
```

## How it works

The key observation is that `pascal` is a `parameter` — a named constant. Its
initializer must therefore be a *constant expression*, which means the compiler
evaluates every entry while it is compiling. At run time there is no arithmetic
left to do; the executable simply prints nine rows of pre-computed integers.

Don't take my word for it — [see for yourself on Compiler
Explorer](https://godbolt.org/z/TKdMP41rd). The assembly contains no loops and
no multiplications, just the finished table sitting in the data section as 81
integer literals (row by row, exactly as printed):

```asm
_QQroX9x9xi4X0:
        .long   1
        .long   0
        .long   0
        ...
        .long   28
        .long   8
        .long   1
```

Reading the expression from the inside out:

- `product([(i, integer :: i = n-k+1, n)])` forms the falling product
  $n(n-1)\cdots(n-k+1) = n!\,/\,(n-k)!$.
- `product([(i, integer :: i = 1, k)])` forms $k!$.
- Their integer quotient is exactly the binomial coefficient $\binom{n}{k}$; the
  division is exact, so no rounding sneaks in. For $k = 0$ both ranges are
  empty, and the *empty product* is `1` — precisely the value we want for
  $\binom{n}{0}$.
- The two nested implied-`do` loops enumerate every coefficient for
  $0 \le n, k \le \mathtt{nmax}$, with $k$ innermost, so the flat list is laid
  out one triangle row after another. `reshape` then fills the square array in
  Fortran's column-major order, which lands each printed row in one memory
  column — element `pascal(k, n)` holds $\binom{n}{k}$. Since `write` emits
  array elements in that same storage order, a single statement prints the
  triangle row by row.

### Why Fortran 2018?

The youngest ingredient is the ability to **declare the type of an implied-`do`
index directly inside the array constructor** — the `integer :: i = ...`,
`integer :: k = ...`, and `integer :: n = ...` you see above. Fortran 2008
introduced in-place index declarations for `do concurrent` and `forall`;
Fortran 2018 extended them to the implied-`do` loops of array constructors and
`data` statements (see §5.18 of John Reid's [*The New Features of Fortran
2018*](https://wg5-fortran.org/N2151-N2200/ISO-IECJTC1-SC22-WG5_N2161_The_New_Features_of_Fortran_2018.pdf)).
As Steve Lionel has explained [on Fortran
Discourse](https://fortran-lang.discourse.group/t/declare-variables-inside-loops/3395),
"declare" is almost too
strong a word: the index is a construct-scope variable that must be an integer
anyway, so the only real novelty is being able to state its kind in place. The
practical payoff is tidiness — no `integer :: i, k, n` declarations lingering
in the surrounding scope purely for the constructor's benefit, which is
especially welcome when initializing parameters at module scope. The feature
has been on paper since 2018, but compiler support is still thin on the
ground — hence the very recent flang (22.1.8).

### A note on the format

The output edit descriptor `'(9(I6,:,1X))'` prints `9` (that is `nmax + 1`)
integers per line in six-character fields. The colon (`:`) stops the format as
soon as the data list is exhausted, and `1X` inserts a single space between
columns. Getting the repeat count right — `9`, not the default that Fortran
would pick — is what lets the whole table print with a single `write`
statement. It is the one place where the program will not follow `nmax`
automatically: change the parameter and you must touch the format too, as
there is no convenient way to splice an integer into a character constant
expression. (For single digits, `achar(iachar('0') + nmax + 1)` would do it —
but that cure is worse than the disease.)

## Further reading

Compile-time evaluation has plenty of more serious uses than pretty-printing a
triangle. A few good starting points:

- [*Some adventures with compile time evaluation*](https://www.youtube.com/watch?v=zL9sNsjbM-w),
  Mohd Furquan, FortranCon 2021
- [*Computing at compile time*](https://fortran-lang.discourse.group/t/computing-at-compile-time/3044),
  Fortran Discourse
- [*Compile Time Computing*](https://community.intel.com/t5/Intel-Fortran-Compiler/Compile-Time-Computing/td-p/1588060),
  Intel Fortran Compiler Forum

And if you enjoy the triangle itself, it stars in one of my favourite Veritasium
videos, [*The Discovery That Transformed Pi*](https://www.youtube.com/watch?v=gMlf1ELvRzc)
— highly recommended.
