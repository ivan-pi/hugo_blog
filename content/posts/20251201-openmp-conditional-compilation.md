---
title: "OpenMP conditional timing"
date: 2025-11-23
draft: true
---

# Wrapping OpenMP timing functions

Often-times when writing an OpenMP program, I'd like to time sections of the program to analyze the parallel speed-up. 
This requires measuring both the sequential performance (without OpenMP) versus the parallel performance. 

OpenMP is designed to be used in way, such that the same program can be a valid OpenMP and non-OpenMP program. 
This is mainly achieved using directives.
In some circumstances it is necessary to call OpenMP runtime functions, and in those situations it is helpful to use the conditional compilation features.

```fortran
   nthreads = 1
!$ nthreads = omp_get_num_threads()
```

As a side-note; if you plan to use OpenMP, use three elements for spacing. 

It is also possible to the use the full preprocessor syntax, even if non-standard in Fortran.
Most compilers define a preprocessor anyways. 
You can use it like this:

```fortran
#if defined(_OPENMP)
	nthreads = omp_get_num_threads()
#else
	nthreads = 1
#endif
```

Normally I will use the conditional compilation syntax, just because it is easier to read. 
When optimizations are turned on, the compiler dead-code elimination pass should eliminate any redundant statements.

However this doesn't work always.
Take the following function:

```fortran
double precision function walltime()
!$ use omp_lib, only: omp_get_wtime

   call cpu_time(walltime)
!$ walltime = omp_get_wtime()

end function
```

The desired effect would be to call the OpenMP timing function only when OpenMP is turned on.
By inspecting the assembly, we can easily determine, this is not the case. 
The compiler preserves both function calls. 

I'm guessing that because the `cpu_time` function is impure; i.e. it involves the reading of some global register.
As a result, the compiler is not free to eliminate this call. 

The only viable workaround is to use conditional compilation:

```
double precision function walltime()
#if defined(_OPENMP)
   use omp_lib, only: omp_get_wtime
   walltime = omp_get_wtime()
#else
   call cpu_time(walltime)
#endif
end function
```

What about this:

```fortran
!$ if (.true.) then
!$    walltime = omp_get_wtime()
!$ else
      call cpu_time(walltime)
!$ endif
```

## The opposite solution

An opposite solution can be sought by sticking with the OpenMP timing function.
Some compilers support this mode of execution, using the `-qopenmp-stubs` flag.

A stub library used to be part of older OpenMP specs.
The stub routines should only be used when OpenMP directives are not in effect, and the program assumes sequential execution.

We can supply the timer function using an external function:

```
double precision function omp_get_wtime()
	call cpu_time(omp_get_wtime)
! or
!   integer, parameter :: dp = kind(1.0d0)
!	integer(selected_int_kind(18)) :: count, count_rate
!   call system_clock(count,count_rate)
!	omp_get_wtime = real(count,dp) / real(count_rate,dp)
end function
```

One thing you need to watch out for is the name-mangling.
Does your compiler expose Fortran external routines or C ones?
At source-level it is difficult to tell.

By inspection I've determined that Intel compilers use `bind(c)` interfaces.

Compilers supporting OpenMP are free to decide if they will provide modules,
include files with interfaces, or both. The include file is deprecated with OpenMP 6.0 and will be removed in the future.

Stub libraries? Which vendors provide them?


