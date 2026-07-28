If anyone is interested, I was playing around with early exit vectorization recently: https://github.com/llvm/llvm-project/issues/129812

Compilers differ in the choices they make. Manual vectorization using intrinsics or assembly can be profitable in some cases.


Is sorted using SIMD instructions
Author:	Wojciech Muła
Added on:	2018-04-11
http://0x80.pl/notesen/2018-04-11-simd-is-sorted.html


How would this look like with Arm SVE instructions? What aboud RISCV?

Discussions with JA.


Scalar loop

logical function is_sorted_scalar(n,a) result(is_sorted)
    integer, intent(in) :: n
    integer, intent(in) :: a(n)
    integer :: i
    !$omp simd simdlen(8) early_exit
    do i = 2, n
        if (a(i) < a(i-1)) then
            is_sorted = .false.
            return
        end if
    end do
    is_sorted = .true.
end function

Unrolled loop
any function


Array intrinsics

logical function is_sorted_all(n,a) result(is_sorted)
    integer, intent(in) :: n
    integer, intent(in) :: a(n)
    is_sorted = all(a(2:n) >= a(1:n-1))
end function


Unrolled version

Relies on increasing ILP via longer instruction chain and potentially allowing the SLP vectorizer to kick in.

logical function is_sorted_unrolled(n, a) result(is_sorted)
    integer, intent(in) :: n
    integer, intent(in) :: a(n)
    integer :: i

    is_sorted = .true.

    ! Process 4 elements at a time
    do i = 2, n - 3, 4
        if (a(i) < a(i-1) .or. &
            a(i+1) < a(i) .or. &
            a(i+2) < a(i+1) .or. &
            a(i+3) < a(i+2)) then
            is_sorted = .false.
            return
        end if
    end do

    ! Clean up the tail
    do i = i, n
        if (a(i) < a(i-1)) then
            is_sorted = .false.
            return
        end if
    end do
end function


Chunked or blocked approach

logical function is_sorted_chunked(n, a) result(is_sorted)
    integer, intent(in) :: n
    integer, intent(in) :: a(n)
    integer :: i, upper
    integer, parameter :: CHUNK_SIZE = 256 ! Tune to architecture (e.g., 64, 128, 256)

    is_sorted = .true.

    ! Check in chunks to allow SIMD vectorization without huge temp arrays
    do i = 2, n, CHUNK_SIZE
        upper = min(i + CHUNK_SIZE - 1, n)
        if (any(a(i:upper) < a(i-1:upper-1))) then
            is_sorted = .false.
            return
        end if
    end do
end function


Test program

program benchmark

    implicit none
    integer, allocatable :: a(:)

    integer :: i, n

    external :: is_sorted_scalar
    external :: is_sorted_all

    logical :: is_sorted_scalar
    logical :: is_sorted_all

    character(len=32) :: str
    integer :: tmp

    tmp = 0
    n = 20000

    if (command_argument_count() > 0) then
        call get_command_argument(1,str)
        read(str,*) tmp
        if (tmp > 0) n = tmp
    end if
    print *, "n = ",  n

    allocate(a(n))

    ! Fill ascending numbers
    do i = 1, n
        a(i) = i
    end do

    ! Introduce an unsorted value
    a(100) = 1001
    !a(101) = 1000

    call measure(100000,a,is_sorted_scalar,"scalar")
    call measure(100000,a,is_sorted_all,   "all")

contains

    impure subroutine measure(nreps,a,func,name)
        integer, intent(in) :: nreps
        integer, intent(in) :: a(:)
        logical :: func
        character(len=*), intent(in) :: name
        integer(8) :: t1, t2, rate
        real(kind(1.0d0)) :: elapsed
        logical :: res

        character(len=12) :: str

        integer :: k
        call system_clock(t1)
        do k = 1, nreps
            res = func(size(a),a)
        end do
        call system_clock(t2,rate)

        elapsed = (t2 - t1)/real(rate,kind(elapsed))

        str = adjustl(name)
        print '(A12,F12.4,L2)', str, elapsed/nreps*1.e6, res

        ! Time is in microseconds

    end subroutine

end program

