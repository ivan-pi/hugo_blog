-- Minloc test issue ---

https://community.intel.com/t5/Intel-Fortran-Compiler/Incorrect-minloc-maxloc-results-with-ifx-2024-0/td-p/1549287

GodBolt reproducer
https://godbolt.org/z/aWf119h3a

In a recent iteration of LU factorization routine in Fortran, I stumbled into a failing test,

```
 5/12 Test  #5: find_pivot .......................***Failed    0.06 sec
testing find_pivot_maxloc
4
```

The test which was failing was,

```
        ! Empty array
        x = [real(dp) ::]
        res = find_pivot(x, size(x))
        if (res /= 0) error stop 4
```

and the kernel that was failing looked like this,

```
    pure integer function find_pivot_maxloc(a, n) result(ip)
        integer,  intent(in) :: n
        real(dp), intent(in) :: a(n)
        ip = maxloc(abs(a), dim=1)
    end function
```

In BLAS, they use the `IDAMAX` function for this purpose.

One prompt later I had created a small reproducer.
You can check the failing test for yourself in Compiler Explorer: https://godbolt.org/z/aWf119h3a

A quick Google search directed immediately directed me an Intel Fortran Forum thread from 2023: https://community.intel.com/t5/Intel-Fortran-Compiler/Incorrect-minloc-maxloc-results-with-ifx-2024-0/td-p/1549287

As Steve Lionel explains in that thread,

> The issue is that earlier standards didn't specify what happens with zero-sized arrays, and adding checks for that slows code down. Intel has traditionally been reluctant to make changes that reduce performance, though it has happened (one no longer needs /assume:realloc_lhs, for example).  Changing the default here would slow down everyone's MAXLOC/MINLOC, so there will be some resistance.

The suggested fix for this issue, is adding the compiler flag `-standard-semantics`.
Note that the flags `-stand f18` doesn't change semantics and controls diagnostics only.
The issue with the `-standard-semantics` flag is it's a "big hammer" that influences many areas, so it can have an impact on performance in places that you may want to leave as is.

An easy fix for this issue is to just add our own empty check,

```
   ip = 0
   if (n < 1) return
   ip = maxloc(abs(a),dim=1)
```

but now we have the downside of performing two-checks with other compilers.

At the cost of having ugly code, we could guard the new statement like this,

```
#ifdef BAD_COMPILER
	if (n < 1) return
#endif
```

This avoid double-checking, unless circumstances lead us to use -standard-semantics in our build. To avoid that we'd need a new guard depending on the compiler flags, ugh...

Now in practice, within the library, we in fact never call maxloc with an empty arrays, so perhaps the test is pointless to begin with.
But you never know when the day will arrive the function is copied in to a different project and the empty array behaviors comes to bite you.


For future projects consider adding the following settings to your CMake project or response file.

add_compile_options(
  "$<$<COMPILE_LANG_AND_ID:Fortran,Intel,IntelLLVM>:-standard-semantics>")


