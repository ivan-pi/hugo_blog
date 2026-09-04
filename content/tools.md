---
title: "Tools"
---

Small interactive calculators that accompany blog posts. They are plain HTML
pages that run entirely in the browser — nothing is sent anywhere.

## Numerical methods

* [RBF-FD Stencil Sizer](/tools/rbf_fd_stencil_sizer.html) — does your
  RBF-FD stencil fit in L1, L2, or GPU shared memory? Computes the local
  system sizes for any polynomial degree, dimension and precision, and
  checks the LU/LDLT/QR working sets against CPU caches and Nvidia shared
  memory. Companion to the post
  [Sizing RBF-FD Stencils for Modern CPU Caches](/posts/2026/07/sizing-rbf-fd-stencils-for-modern-cpu-caches/).
