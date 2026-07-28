

Performance Analysis of a Stencil Code in C++, Victor Eijkhout & Yojan Chitkara
https://www.ixpug.org/resources/performance-analysis-of-a-stencil-code-in-modern-c

I find it amusing that the plain C variant is still the fastest.


Sapphire Rapids with DDR5 has peak values (from a presentation by McCalpin, also known as Mr STREAM):

copy and scale: 377.4 GB/s
add and triad: 398.3 GB/s.
I've tested a similar 2-d stencil with the ifx compiler,

> OMP_TARGET_OFFLOAD=disabled OMP_NUM_THREADS=112 OMP_PLACES=cores OMP_PROC_BIND=spread ./test_xy_der 8000 8000

OMP teams loop
-----------------------------------------------------v
Iterations: 512
Avg. time (s): 3.1500782E-03
Max. absolute error: 1.268352076597045E-013
Sum of absolute residuals: 3.289868637996711E-006
Sum of squared residuals: 2.573928496287013E-019
Effective Bandwidth (GB/s): 325.1119 


      !$omp target teams loop collapse(2) map(to: f) map(from: f_xy)
      do j = 1, ny
         do i = 1, nx
            f_xy(i,j) = 0.25_wp*(f(i+1,j+1) - f(i-1,j+1) + f(i-1,j-1) - f(i+1,j-1))
         end do
      end do


#define IINDEX( i,j,m,n,b ) ((i)+b)*(n+2*b) + (j)+b

for (...) {
   for (...) {
      out[ IINDEX(i,j,m,n,b) ] = 4*in[ IINDEX(i,j,m,n,b) ]
         - in[ IINDEX(i-1,j,m,n,b) ] - in[ IINDEX(i+1,j,m,n,b) ] - in[ IINDEX(i,j-1,m,n,b) ] - in[ IINDEX(i,j+1,m,n,b) ];
   }
}


I forgot how I compiled it, but with -O3 -xSAPPHIRERAPIDS, it was using AVX2 registers. If I add -mprefer-vector-width=512 it uses AVX512: https://godbolt.org/z/PKeKr5jve
But I think the C/C++ would also vectorize. Maybe adding __restrict is necessary or -no alias switch.


Questions: 
- do we need AVX512 to reach the memory-bound limit or will even "worse" x86 code become memory bound eventually when all 112 cores go for memory


The Intel compilers have a -novec option to disable vectorization, but I didn't check. The 3-d case surely needs cache-blocking, and use of layer conditions for good performance (https://rrze-hpc.github.io/layer-condition/).

Josef: Just had a look at the assembly output of your Fortran code. This does an unroll of factor 64 for the inner-most loop (8 stores of 512bit values). That is, just one inner loop code does 64 stencils at once and goes over 512 byte. So your nx also must be a multiple of 64 to stay in the fast path (not taking splitting up by OpenMP into account). Sounds a bit too aggressive for me? I cannot believe you need this high unrolling factor to actually see a reduction in the loop overhead (the interleaving using all available registers may be worth it)

ifx 2024.0.0 obviously does this by default for Sapphire Rapids
A similar C code with gcc 14 and -mavx512f only does unroll of 8 (ie. one AVX512 store)


The (really ugly) C code: https://godbolt.org/z/b8ahPKKhc
Maybe it has to do that this C code goes over a sub-rectangle of the 2d domain

I really love the (+Add new) -> Control Flow Graph button in Compiler Explorer. Makes it very easy to follow the assembly listing. Recently this feature started working with clang too.

.LBB0_5:
        vmovupd zmm2, zmmword ptr [rdi + 8*rdx - 208]
        vmovupd zmm3, zmmword ptr [rdi + 8*rdx - 144]
        vmovupd zmm4, zmmword ptr [rdi + 8*rdx - 80]
        vmovupd zmm5, zmmword ptr [rdi + 8*rdx - 16]
        vaddpd  zmm2, zmm2, zmmword ptr [rdi + 8*rdx - 192]
        vaddpd  zmm3, zmm3, zmmword ptr [rdi + 8*rdx - 128]
        vaddpd  zmm4, zmm4, zmmword ptr [rdi + 8*rdx - 64]
        vaddpd  zmm5, zmm5, zmmword ptr [rdi + 8*rdx]
        vmovupd zmm6, zmmword ptr [r13 + 8*rdx - 192]
        vmovupd zmm7, zmmword ptr [r13 + 8*rdx - 128]
        vmovupd zmm8, zmmword ptr [r13 + 8*rdx - 64]
        vmovupd zmm9, zmmword ptr [r13 + 8*rdx]
        vaddpd  zmm6, zmm6, zmmword ptr [rax + 8*rdx - 192]
        vaddpd  zmm7, zmm7, zmmword ptr [rax + 8*rdx - 128]
        vaddpd  zmm8, zmm8, zmmword ptr [rax + 8*rdx - 64]
        vaddpd  zmm9, zmm9, zmmword ptr [rax + 8*rdx]
        vmulpd  zmm6, zmm6, zmm1
        vmulpd  zmm7, zmm7, zmm1
        vmulpd  zmm8, zmm8, zmm1
        vmulpd  zmm9, zmm9, zmm1
        vfmadd231pd     zmm6, zmm1, zmm2
        vfmadd231pd     zmm7, zmm1, zmm3
        vfmadd231pd     zmm8, zmm1, zmm4
        vfmadd231pd     zmm9, zmm1, zmm5
        vmovupd zmmword ptr [rsi + 8*rdx - 192], zmm6
        vmovupd zmmword ptr [rsi + 8*rdx - 128], zmm7
        vmovupd zmmword ptr [rsi + 8*rdx - 64], zmm8
        vmovupd zmmword ptr [rsi + 8*rdx], zmm9
        add     rdx, 32
        cmp     r14, rdx
        jne     .LBB0_5


Refactored examples,
https://godbolt.org/z/PW35T37Ys


