---
title: "Evaluating the closed form coefficients of Laguerre polynomials"
date: "2021-12-29"
draft: false
tags: ["Laguerre", "Polynomials", "Fortran"]
mathjax: true
katex: false
---

# Evaluating the closed form coefficients of Laguerre polynomials

For some numerical applications it can be useful to work with the closed form 
expression for Laguerre polynomials. The closed form is given by

{{< neq 1 "L_n(x) = \sum_{k=0}^n {n \choose k} \frac{(-1)^k}{k!} x^k">}}

We can evaluate the coefficients with the help of the factorial formula

{{< neq 2 "\binom{n}{k} = \frac{n!}{k!\,(n-k)!}">}}

Since $n$ and $k$ are both integers, the coefficients are rational numbers.
For most computational applications we will likely only need to work with
floating point approximations of the coefficients.

When evaluating the coefficients using the factorial formula we should 
be careful to avoid overflow. For example if we try to compute $$n!$$ using default Fortran integers (32-bit), it will only be possible to calculate coefficients for $n \leq 12$.

To avoid such issues we can calculate the coefficients using the 
the gamma function $\Gamma$ and the logarithm thereof. This follows from the helpful observation that for integer arguments

{{< neq 3 "\Gamma(n+1) = n!">}}

For the coefficients of $L_n(x)$, a straightforward Fortran implementation might look as follows:

```fortran
  pure function lagcoefs(n) result(a)
    integer, intent(in) :: n
    real :: a(0:n)
    integer :: k

    do k = 0, n
      a(k) = (-1)**k * exp( &
            log_gamma(real(n+1)) &
        - 2*log_gamma(real(k+1)) &
          - log_gamma(real(n-k+1)))
    end do
  end function
```

where we have used the properties of logarithms to transform the quotient into 
subtraction.  The input `n` should be a non-negative integer value.
The coefficients returned by the procedure are given in _ascending_ order of
powers of $x$.

A similar procedure can be written for the derivative of the Laguerre polynomial.
These are given be the expression 

{{<neq 4 "L'_n(x) = \sum_{k=0}^n \binom{n}{k}\frac{(-1)^k}{k!} k x^{k-1}">}}


Here we should emphasize that the $i$-th derivative of a Laguerre polynomial
is polynomial of order ${n - i}$ (a polynomial of order $n$
is described by $n+1$ coefficients).

The implementation can also be adapted easily to return the coefficients of 
the generalized Laguerre polynomials with the following closed form expression

{{< neq 5 "L_n^{(\alpha)}(x) = \sum_{k=0}^n (-1)^k \binom{n + \alpha}{ n - k} \frac{x^k}{k!}" >}}



