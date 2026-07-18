---
title: "What Does MAXLOC Return for an Empty Array?"
date: 2026-07-18
draft: true
tags: ["Fortran", "maxloc", "minloc", "Intel"]
---

While iterating on an LU factorization routine in Fortran the other day, I stumbled into a failing test:

```
 5/12 Test  #5: find_pivot .......................***Failed    0.06 sec
testing find_pivot_maxloc
4
```

The `4` on the second line is the code from an `error stop`, and it came from this innocent-looking case:

```fortran
! Empty array
x = [real(dp) ::]
res = find_pivot(x, size(x))
if (res /= 0) error stop 4
```

An empty array is a natural edge case for a pivot search, so the test simply asserts that searching an empty array returns `0`, our sentinel for "no pivot found." The kernel under test was a one-liner built around the `maxloc` intrinsic:

```fortran
pure integer function find_pivot_maxloc(a, n) result(ip)
    integer,  intent(in) :: n
    real(dp), intent(in) :: a(n)
    ip = maxloc(abs(a), dim=1)
end function
```

Finding the index of the entry with the largest magnitude is exactly the partial-pivoting step in Gaussian elimination. It is such a common operation that the reference BLAS ships a dedicated routine for it, [`IDAMAX`](https://github.com/Reference-LAPACK/lapack/blob/master/BLAS/SRC/idamax.f), used throughout LAPACK's factorization routines. Hold that thought---we'll come back to `IDAMAX` shortly.

## Reproducing the surprise

One prompt later I had a minimal reproducer, which you can run for yourself in [Compiler Explorer](https://godbolt.org/z/aWf119h3a). Compiled with the Intel Fortran compiler (`ifx`) using its default settings, `maxloc(abs(a), dim=1)` on a zero-sized array returns `1` rather than `0`. That single off-by-one sentinel is enough to trip the assertion and abort the test.

At first glance this looks like a plain compiler bug. It isn't---it's a deliberate, decades-old default.

## Why does this happen?

A quick web search turned up a relevant [Intel Fortran forum thread](https://community.intel.com/t5/Intel-Fortran-Compiler/Incorrect-minloc-maxloc-results-with-ifx-2024-0/td-p/1549287). As Steve Lionel explains there:

> The issue is that earlier standards didn't specify what happens with zero-sized arrays, and adding checks for that slows code down. Intel has traditionally been reluctant to make changes that reduce performance, though it has happened (one no longer needs /assume:realloc_lhs, for example). Changing the default here would slow down everyone's MAXLOC/MINLOC, so there will be some resistance.

Here is the history in a nutshell. Fortran 95 and earlier let `MAXLOC`/`MINLOC` return `1` for a zero-sized array (or when every element of a `MASK` is false), and that was the compiler's behavior. Fortran 2003 tightened this: if the array has size zero, every element of the result shall be zero. Intel added the standard-conforming behavior behind the [`-assume [no]old_maxminloc`](https://www.intel.com/content/www/us/en/docs/fortran-compiler/developer-guide-reference/2025-0/maxloc.html) switch, but kept the *old* behavior---returning `1`---as the default, because the extra check for the empty case costs a little performance in the hot path.

So `ifx` isn't so much wrong as old-fashioned by default. The `4` in my test output was the compiler faithfully reproducing 1990s semantics.

## Fixing it

There are a few ways out, depending on how much you value portability versus a clean hot path.

**Flip the switch.** The most direct fix is to ask the compiler for the modern semantics:

```
-assume noold_maxminloc
```

The fix suggested in the forum thread is the broader `-standard-semantics` flag, which turns on `noold_maxminloc` along with a whole batch of other standard-conforming behaviors. That makes it something of a "big hammer": it changes semantics in many areas at once, so it can have knock-on effects---including on performance---in places you might have preferred to leave alone. Note also that the diagnostic flag `-stand f18` does *not* change semantics; it only controls warnings.

**Guard it yourself.** If you'd rather not depend on a build flag, add your own empty check:

```fortran
pure integer function find_pivot_maxloc(a, n) result(ip)
    integer,  intent(in) :: n
    real(dp), intent(in) :: a(n)
    ip = 0
    if (n < 1) return
    ip = maxloc(abs(a), dim=1)
end function
```

The downside is that on a standard-conforming compiler you now pay for the check twice: once in your guard, and once again inside `maxloc`.

If that redundancy bothers you, you can hide the guard behind the preprocessor:

```fortran
#ifdef BAD_COMPILER
    if (n < 1) return
#endif
```

This avoids the double check---until the day someone builds with `-standard-semantics`, at which point `maxloc` guards the empty case too and we are back to checking twice. Papering over that would mean tying the macro to the exact compiler flags in play. Ugh.

Which brings us back to `IDAMAX`. If you peek at the reference BLAS implementation, the very first thing it does is exactly the guard we just reinvented:

```fortran
INTEGER FUNCTION IDAMAX(N,DX,INCX)
    ...
    IDAMAX = 0
    IF (N.LT.1 .OR. INCX.LE.0) RETURN
    IDAMAX = 1
    ...
```

A routine that has been in service since the late 1970s already returns `0` for an empty input. The explicit check has been there all along; the modern intrinsic just tucked it behind a compiler switch.

## Is the test even worth it?

In practice, within the library we never actually call `maxloc` on an empty array---the pivot search always runs over a non-empty panel. By that logic the test is arguably pointless, and I could delete it and move on.

But "we never do that" has a way of expiring. The day someone copies this kernel into another project---where the empty case *can* occur---the old-array behavior is waiting to bite. A cheap test that pins down the contract for the edge case is good insurance, even if today's callers never exercise it.

## A recommendation for new projects

For new work I have settled on flipping the switch at the build level and letting the intrinsic behave the way the standard says. In CMake, you can scope the flag to just the Intel compilers:

```cmake
# Make ifx/ifort return 0 from MAXLOC/MINLOC on zero-sized arrays,
# matching the Fortran 2003+ standard.
add_compile_options(
  "$<$<COMPILE_LANG_AND_ID:Fortran,Intel,IntelLLVM>:-assume;noold_maxminloc>")
```

If you would rather opt into the full set of modern semantics, swap `-assume;noold_maxminloc` for `-standard-semantics`---just be aware that it changes more than this one corner.

Either way, the lesson is an old one: intrinsics have contracts, those contracts have edges, and the edges are where the interesting bugs live.
