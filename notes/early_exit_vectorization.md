If anyone is interested, I was playing around with early exit vectorization recently: https://github.com/llvm/llvm-project/issues/129812

Compilers differ in the choices they make. Manual vectorization using intrinsics or assembly can be profitable in some cases.


Is sorted using SIMD instructions
Author:	Wojciech Muła
Added on:	2018-04-11
http://0x80.pl/notesen/2018-04-11-simd-is-sorted.html


How would this look like with Arm SVE instructions? What aboud RISCV?

Discussions with JA.