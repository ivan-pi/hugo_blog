---
title: "Code development"
markup: "mmark"
---

In my free time I like to work on scientific coding projects in Fortran.

## Fortran interfaces
* [nlopt](https://github.com/ivan-pi/nlopt)
* [METIS](https://github.com/ivan-pi/fmetis)
* [FLANN](https://github.com/ivan-pi/flann):
Fast Library for Approximate Nearest Neighbors (original library [here](http://people.cs.ubc.ca/~mariusm/flann))


## Legacy code
* [Algorithm 494: PDEONE](https://github.com/ivan-pi/TOMS-494) is a subroutine developed by Sincovec and Madsen in 1975 for solving one-dimensional systems of PDEs using the method of lines. Second-order centered difference approximations are used to discretize the spatial variable and yield a system of ordinary differential equations that can be integrated in time with a robust ODE integrator (like LSODE).
* [Algorithm 675](https://github.com/ivan-pi/TOMS-Algorithm-675): Fortran subroutines for computing the square root covariance filter and square root information filter in dense and hessenberg forms; codes are provided for the square root covariance filter and the square root information filter.
* [Quadrature routines from Stroud & Secrest](https://github.com/ivan-pi/stroud_quad) - An updated version of the routines from the book *Gaussian quadrature formulas* by A. H. Stroud and D. Secrest published in 1966. Includes routines for generatics the knots and weights of the classic Jacobi, Laguerre, and Hermite quadratures.
* [Least squares solvers from Lawson & Hanson](https://github.com/ivan-pi/fortran_lsp) - This package contains the routines from the book *Solving least squares problems* by Lawson and Hanson (1995). Most of the routines date back to the 1974 version of the book and were developed for use at the NASA Jet Propulsion Laboratory in California, Pasadena. I have tried to modernize the interfaces of most of the subroutines. The non-negative least squares solver `nnls` appears also in [`scipy.optimize.nnls`](https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.nnls.html).

