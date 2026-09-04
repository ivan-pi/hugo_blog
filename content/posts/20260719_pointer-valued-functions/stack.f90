! stack.f90 --
!   Companion code for the blog post "Assigning to a Function Call:
!   Pointer-Valued Functions in Fortran" (https://ivan-pi.github.io).
!
!   Build with: gfortran -std=f2018 -Wall stack.f90
!
module stack_type
implicit none
public

type :: stack
    private
    integer :: i = 0
    integer :: a(1000)
end type

contains

    logical function is_empty(s)
        type(stack), intent(in) :: s
        is_empty = s%i == 0
    end function

    logical function is_full(s)
        type(stack), intent(in) :: s
        is_full = s%i == 1000
    end function

    function push(s) result(k)
        type(stack), intent(inout), target :: s
        integer, pointer :: k
        if (is_full(s)) error stop "Stack overflow"
        s%i = s%i + 1
        k => s%a(s%i)
    end function

    function pop(s) result(k)
        type(stack), intent(inout) :: s
        integer :: k
        if (.not. is_empty(s)) then
            k = s%a(s%i)
            s%i = s%i - 1
        end if
    end function

end module

program demo
use stack_type

type(stack), target :: mystack

push(mystack) = 1
push(mystack) = 2
push(mystack) = 3

do while (.not. is_empty(mystack))
    print *, pop(mystack)
end do

end program
