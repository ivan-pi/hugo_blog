---
title: "Code development"
---

In my free time I like to work on scientific coding projects in Fortran.

## Fortran interfaces

Fortran 2003 added features for interoperability with the C programming language. These can be accesed through the intrinsic `iso_c_binding` module and allow smooth interfacing between the two languages for a certain set of interoperable types. This way Fortran programmers can gain access to the numerous libraries written in C/C++ and vice versa.

Using the C-Fortran interoperability I have written Fortran interfaces for the following (scientific) software libraries:

* [nlopt](https://github.com/ivan-pi/nlopt): library for nonlinear optimization
* [METIS](https://github.com/ivan-pi/fmetis): Serial Graph Partitioning and Fill-reducing Matrix Ordering
* [FLANN](https://github.com/ivan-pi/flann):
Fast Library for Approximate Nearest Neighbors (original library [here](http://people.cs.ubc.ca/~mariusm/flann))
* [libdogleg-f](https://github.com/ivan-pi/libdogleg-f): Fortran bindings to libdogleg, a large-scale nonlinear least-squares optimization library
* [blis-fortran](https://github.com/ivan-pi/blis-fortran): Fortran bindings for BLIS generated using Coccinelle (the subject of my [FOSDEM 2025 talk](https://archive.fosdem.org/2025/schedule/event/fosdem-2025-6509-easier-api-interoperability-writing-a-bindings-generator-to-c-c-with-coccinelle/))
* [Fortran-KaHIP-Interface](https://github.com/ivan-pi/Fortran-KaHIP-Interface): A modern Fortran interface to the [KaHIP](https://github.com/KaHIP) graph partitioning framework


## Python bindings

* [zvode](https://ivan-pi.github.io/zvode/): Python bindings to the classic ZVODE ODE solver.
* [phs_poly](https://pypi.org/project/phs-poly/): Procedures for generating RBF-FD weights for derivative calculations.


## Fortran tooling

* [fpm-deps and fpm-tree](https://ivan-pi.github.io/fpm-deps/): `fpm-deps` generates dependency graphs of [fpm](https://fpm.fortran-lang.org/) packages, with `fpm-tree` as a companion tool.


## Legacy code

* [stiff3](https://github.com/ivan-pi/stiff3): Adaptive solver for stiff systems of ODEs using semi-implicit Runge-Kutta method of third order.
* [bode](https://github.com/ivan-pi/bode): A low-order adaptive solver for implicit ODEs.
* [y12m](https://github.com/ivan-pi/y12m): Solution of Large and Sparse Systems of Linear Algebraic Equations.
* [kdtree2](https://github.com/ivan-pi/kdtree2): A kd-tree implementation in Fortran by Matthew B. Kennel. The original was archived and is now maintained, evolved, and tested by me with other contributions.
* [pdecheb](https://github.com/ivan-pi/pdecheb): Chebyshev Polynomial Software for Elliptic-Parabolic Systems of PDEs.
* [Algorithm 494: PDEONE](https://github.com/ivan-pi/TOMS-494) is a subroutine developed by Sincovec and Madsen in 1975 for solving one-dimensional systems of PDEs using the method of lines. Second-order centered difference approximations are used to discretize the spatial variable and yield a system of ordinary differential equations that can be integrated in time with a robust ODE integrator (like LSODE).
* [Algorithm 675](https://github.com/ivan-pi/TOMS-Algorithm-675): Fortran subroutines for computing the square root covariance filter and square root information filter in dense and hessenberg forms; codes are provided for the square root covariance filter and the square root information filter.
* [Quadrature routines from Stroud & Secrest](https://github.com/ivan-pi/stroud_quad) - An updated version of the routines from the book *Gaussian quadrature formulas* by A. H. Stroud and D. Secrest published in 1966. Includes routines for generatics the knots and weights of the classic Jacobi, Laguerre, and Hermite quadratures.
* [Least squares solvers from Lawson & Hanson](https://github.com/ivan-pi/fortran_lsp) - This package contains the routines from the book *Solving least squares problems* by Lawson and Hanson (1995). Most of the routines date back to the 1974 version of the book and were developed for use at the NASA Jet Propulsion Laboratory in California, Pasadena. I have tried to modernize the interfaces of most of the subroutines. The non-negative least squares solver `nnls` appears also in [`scipy.optimize.nnls`](https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.nnls.html).

