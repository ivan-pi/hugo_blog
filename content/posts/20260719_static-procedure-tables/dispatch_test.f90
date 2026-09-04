! dispatch_test.f90 --
!   Dispatch table using procedure pointers
!
! To compile and run:
!
!   flang dispatch_test.f90 && ./a.out
!
! As of Nov 2025, only flang and NAG accept the static dispatch table.

module funcs
abstract interface
    function retchar()
       character(len=1) :: retchar
    end function
end interface
contains
    function a()
        character(len=1) :: a
        a = 'a'
    end function
    function b()
        character(len=1) :: b
        b = 'b'
    end function
    function c()
        character(len=1) :: c
        c = 'c'
    end function
end module

module dispatch_table
use funcs
implicit none
private

public :: table
public :: build_table, pc

! Procedure container
type :: pc
    procedure(retchar), pointer, nopass :: rc => null()
end type

! Static dispatch table
type(pc), parameter :: table(3) = [pc(a),pc(b),pc(c)]

! According to J3/24-007, section 7.5.10, a procedure target
! can be used in the structure constructor.

contains

    ! Dynamic dispatch table
    function build_table() result(table)
        type(pc) :: table(3)
        table = [pc(a),pc(b),pc(c)]
    end function

end module

program test
    use dispatch_table, only: pc, build_table
    implicit none
    type(pc) :: table(3)
    table = build_table() ! Dynamic table
    associate(abc => &
        table(1)%rc()//table(2)%rc()//table(3)%rc())
        if (abc /= 'abc') stop 1
    end associate

    block
        use dispatch_table, only: table ! Static table
        associate(abc => &
            table(1)%rc()//table(2)%rc()//table(3)%rc())
            if (abc /= 'abc') stop 2
        end associate
    end block

    print *, 'PASS'
end program
