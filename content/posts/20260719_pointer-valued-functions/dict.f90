! dict.f90 --
!   Companion code for the blog post "Assigning to a Function Call:
!   Pointer-Valued Functions in Fortran" (https://ivan-pi.github.io).
!
!   A toy dictionary whose entries are created on first access,
!   in the spirit of std::map::operator[] in C++.
!
!   Build with: gfortran -std=f2018 -Wall dict.f90
!
module dict_type
implicit none
private
public :: dict

type :: pair
    character(len=:), allocatable :: key
    integer :: val
end type

type :: dict
    private
    type(pair), allocatable :: pairs(:)
contains
    procedure :: of
end type

contains

    function of(self, key) result(v)
        class(dict), intent(inout), target :: self
        character(len=*), intent(in) :: key
        integer, pointer :: v
        integer :: i
        if (.not. allocated(self%pairs)) allocate(self%pairs(0))
        do i = 1, size(self%pairs)
            if (self%pairs(i)%key == key) then
                v => self%pairs(i)%val
                return
            end if
        end do
        self%pairs = [self%pairs, pair(key, 0)]
        v => self%pairs(size(self%pairs))%val
    end function

end module

program demo
use dict_type
implicit none

type(dict), target :: fruit

fruit%of("apples") = 3
fruit%of("oranges") = 5
fruit%of("apples") = fruit%of("apples") + 1

print *, fruit%of("apples"), fruit%of("oranges")

end program
