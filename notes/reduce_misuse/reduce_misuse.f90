module mymod
integer, parameter :: dp = kind(1.0d0)
contains
pure function newton_step(acc, dummy) result(y)
  real(dp), intent(in) :: acc, dummy
  real(dp) :: y
  y = acc - (acc*acc - 2.0_dp)/(2.0_dp*acc)
end function
end module mymod

program foo
use mymod, only: dp, newton_step
implicit none
integer :: i
real(dp) :: sqrt2

sqrt2 = reduce([(1.0_dp, i=1,20)], newton_step, ordered=.true.) 
print *, sqrt2, sqrt(2.0_dp)

end program
