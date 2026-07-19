! recursive_callback.f90 --
!   A constant procedure table calling itself through a submodule
!
! To compile and run:
!
!   nagfor recursive_callback.f90 && ./a.out

module recursive_callback
implicit none
private

public :: my_f

abstract interface
    recursive subroutine ffunc(i)
      integer, intent(in) :: i
    end subroutine
end interface

interface
   recursive module subroutine a(i)
      integer, intent(in) :: i
   end subroutine
end interface

type :: callback
    procedure(ffunc), pointer, nopass :: f
end type

type(callback), parameter :: my_f = callback(a)

end module

submodule (recursive_callback) impl
contains
module procedure a
  print *, i
  if (i < 1) return
  call my_f%f(i-1)  ! same as `call a(i)`
end procedure
end submodule

program test
use recursive_callback, only: my_f
call my_f%f(5)    ! same as call a(5)
end program
