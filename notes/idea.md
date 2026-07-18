# Is Fortran all we need for performance?

There are many myths out in the wild:

- you just need C++
- you just need Fortran
- you just need BLAS

Telling the true from the false is

Design an API which encapsulates the operations you need.
If performance is not good enough, seek to implement them by other means.

In practice we see that array reductions hardly reach the peak.

Even a memory copy won't use nontemporal stores unless instructed too.

