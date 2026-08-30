---
title: "Sizing RBF-FD Stencils for Modern CPU Caches"
date: 2026-07-18
draft: false
tags:
  - "rbf-fd"
  - "numerical-methods"
  - "hpc"
  - "cpu-cache"
  - "linear-algebra"
---

One of the benefits of the RBF-FD methods compared to grid-based finite differences is it is straightforward to change the order of accuracy via the augmented polynomials.
The number of monomial terms in the augmented polynomial basis is given by the [triangular numbers](https://en.wikipedia.org/wiki/Triangular_number) in 2-d and the [tetrahedral numbers](https://en.wikipedia.org/wiki/Tetrahedral_number) in 3-d.
For a basis complete through total degree $p$ there are $(p+1)(p+2)/2$ terms in 2-d and $(p+1)(p+2)(p+3)/6$ terms in 3-d.
The number of terms can also be read from Pascal's triangle/pyramid.

For the RBF stencil size a common heuristic is to use twice the number of polynomials terms.
This rule of thumb goes back to [Flyer, Barnett, and Wicker (2016)](https://doi.org/10.1016/j.jcp.2016.02.078).
While it is a standard starting point for stencil sizing, the relationship between accuracy, computational time, and monomial augmentation remains an active area of research.
Readers can find more information in the analysis by [Jančič, Slak, and Kosec (2021)](https://doi.org/10.1007/s10915-020-01401-y) and citing works.
For a broad study of how the many RBF-FD parameters interact — stencil size, polynomial degree, RBF choice, node distribution — [Le Borne and Leinen (2023)](https://doi.org/10.1007/s10915-023-02123-7) is a good source.

The tables below show how the RBF-FD matrix dimensions varies for 2-D and 3-D RBF-FD approximation.
We also include the storage size of the matrices for 32- and 64-bit floats.

**2-D RBF-FD approximation**

| Poly order | Number of monomials | Matrix size (RBF + poly) | Storage - fp32 (KB) | Storage - fp64 (KB) |
|------------|---------------------|------------|---------------------|---------------------|
| 1          | 3                   | 9          | 0.316               | 0.633               |
| 2          | 6                   | 18         | 1.266               | 2.531               |
| 3          | 10                  | 30         | 3.516               | 7.031               |
| 4          | 15                  | 45         | 7.910               | 15.820              |
| 5          | 21                  | 63         | 15.504              | 31.008              |
| 6          | 28                  | 84         | 27.563              | 55.125              |
| 7          | 36                  | 108        | 45.563              | 91.125              |
| 8          | 45                  | 135        | 71.191              | 142.383             |
| 9          | 55                  | 165        | 106.348             | 212.695             |
| 10         | 66                  | 198        | 153.141             | 306.281             |

**3-D RBF-FD approximation**

| Poly order | Number of monomials | Matrix size (RBF + poly) | Storage - fp32 (KB) | Storage - fp64 (KB) |
|------------|---------------------|-------------------------|---------------------|---------------------|
| 1          | 4                   | 12                      | 0.563               | 1.125               |
| 2          | 10                  | 30                      | 3.516               | 7.031               |
| 3          | 20                  | 60                      | 14.063              | 28.125              |
| 4          | 35                  | 105                     | 43.066              | 86.133              |
| 5          | 56                  | 168                     | 110.250             | 220.500             |
| 6          | 84                  | 252                     | 248.063             | 496.125             |
| 7          | 120                 | 360                     | 506.250             | 1012.500            |
| 8          | 165                 | 495                     | 957.129             | 1914.258            |
| 9          | 220                 | 660                     | 1701.563            | 3403.125            |
| 10         | 286                 | 858                     | 2875.641            | 5751.281            |

When computing the RBF-FD approximation weights via LU factorization or other forms of factorization (i.e. block Cholesky) the matrix will reside in the L1 or L2 cache.
The maximum matrix size that fits in cache also depends on the number of right-hand sides (operators) being solved simultaneously, as those vectors must also share the cache.

Here are the L1 data cache sizes of a few recent CPU architectures:

| CPU                      | L1D Cache Size (KB) |
|--------------------------|---------------------|
| Apple M-series (P-core)  | 128                 |
| Nvidia Grace             | 64                  |
| Fujitsu A64FX            | 64                  |
| Intel Granite Rapids     | 48                  |
| Intel Sapphire Rapids    | 48                  |
| Intel Core 13th/14th Gen | 48                  |
| Intel Core 11th Gen      | 48                  |
| AMD Zen 5                | 48                  |
| AMD Zen 4                | 32                  |

The figure below plots the matrix storage against polynomial order up to 12,
with the L1 data cache sizes drawn as horizontal references. Storage scales with
the *square* of the number of polynomial terms, so the vertical axis is
logarithmic.

<figure>
<object type="image/svg+xml" data="/images/rbf-fd-matrix-sizes.svg" style="display:block; width:100%; max-width:840px; aspect-ratio:3/2; height:auto; margin-inline:auto;">
<img src="/images/rbf-fd-matrix-sizes.svg" alt="Log-scale plot of RBF-FD system-matrix storage in kilobytes versus polynomial order from 1 to 12, for 2-D and 3-D approximations in single and double precision, with horizontal lines marking the 32, 64 and 128 KB L1 data cache sizes of recent CPUs." />
</object>
<figcaption>System-matrix storage vs. polynomial order for the <em>twice the number of polynomial terms</em> stencil heuristic, in single (fp32) and double (fp64) precision. Horizontal lines mark representative L1 data cache sizes. <em>Interactive:</em> hover to read off values, and click a legend entry to toggle a curve.</figcaption>
</figure>

For polynomials below order 6 in 2D (or 4 in 3D) the RBF-FD matrices fit comfortably in the lowest cache level.
The Apple M-series and recent ARM servers like the Nvidia Grace or Fujitsu A64FX have a slight advantage due to the larger L1 cache sizes.
Intel and AMD CPUs used 32 KB L1 data caches for more than a decade.
AMD increased the size only recently with the Zen 5 series launched in 2024.
Intel made the upgrade from 32 KB to 48 KB in the Sunny Cove architecture launched in 2019.

(Note: Apples's efficiency cores (E-cores) use smaller 64 kB L1D caches.
Intel's efficiency cores have remained at 32 kB L1 data caches. )

---

*Correction (2026-08-30): the monomial counts in the tables and the figure were originally shifted by one order — the row labelled order $p$ held the count for degree $p-1$, so order 2 in 2-D showed 3 terms instead of 6. The tables and figure have been recomputed, which moves the cache-fit thresholds down by one order as well. The stencil-size heuristic was also misattributed to Grady Wright; it originates with Flyer, Barnett, and Wicker.*