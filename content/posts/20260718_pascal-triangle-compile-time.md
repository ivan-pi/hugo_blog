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
integer, parameter :: N = 8
character(len=*), parameter :: fmt = '(9(I6,:,1X))'
integer, parameter :: c(0:N, 0:N) = &
    reshape([([(product([(jj, integer :: jj=nn-k+1,nn)]) / &
               product([(jj, integer :: jj=1,k)]),  &
               integer :: nn=0,N)], integer :: k=0,N)], [N+1, N+1], order=[2,1])
write(*,fmt) c
end
```

Compiling and running it with [flang](https://github.com/llvm/llvm-project)
22.1.8:

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

The key observation is that `c` is a `parameter` — a named constant. Its
initializer must therefore be a *constant expression*, which means the compiler
evaluates every entry while it is compiling. At run time there is no arithmetic
left to do; the executable simply prints nine rows of pre-computed integers.

Reading the expression from the inside out:

- `product([(jj, integer :: jj=nn-k+1,nn)])` forms the rising product
  $n(n-1)\cdots(n-k+1) = n!\,/\,(n-k)!$.
- `product([(jj, integer :: jj=1,k)])` forms $k!$.
- Their integer quotient is exactly the binomial coefficient $\binom{n}{k}$; the
  division is exact, so no rounding sneaks in. For $k = 0$ both ranges are
  empty, and the *empty product* is `1` — precisely the value we want for
  $\binom{n}{0}$.
- The two nested implied-`do` loops enumerate every coefficient for
  $0 \le n, k \le N$, and `reshape(..., [N+1, N+1], order=[2,1])` packs that flat
  list into the square array `c`.

### Why Fortran 2023?

The program relies on a Fortran 2023 feature: you may **declare the type of an
implied-`do` variable directly inside the array constructor**, which is the
`integer :: jj=...`, `integer :: nn=...`, and `integer :: k=...` you see above.
This scopes the loop index to the constructor itself and keeps the whole
expression a constant expression — a hard requirement for initializing a
`parameter`. You will need a compiler with Fortran 2023 support to build it (I
used flang 22.1.8).

### A note on the format

The output edit descriptor `'(9(I6,:,1X))'` prints `9` (that is `N + 1`)
integers per line in six-character fields. The colon (`:`) stops the format as
soon as the data list is exhausted, and `1X` inserts a single space between
columns. Getting the count right — `9`, not the default that Fortran would pick —
is what lets the whole table print with a single `write` statement. I admit the
variable names are not the prettiest, but the one-liner earns its keep.

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
