! real_literal.f90 - Recognizing real literals with a state machine
!
! The finite automaton is borrowed from page 4 of the pdf
! https://pages.cs.wisc.edu/~fischer/cs536.s06/lectures/Lecture07.4up.pdf
!
! To compile and run:
!
!   flang real_literal.f90 && ./a.out
!
! As of Nov 2025, only flang and NAG support the static dispatch table.

module real_literals
implicit none
private
public :: is_real_literal

! States of the automaton
integer, parameter :: err          = 0  ! not a real literal
integer, parameter :: start        = 1  ! nothing seen yet
integer, parameter :: leading_dot  = 2  ! seen '.', a digit must follow
integer, parameter :: integer_part = 3  ! reading digits before the dot
integer, parameter :: fraction     = 4  ! seen a dot with digits around it

contains

    ! Transition functions, one per state; each maps the
    ! current character c to the next state.

    function from_start(c) result(next)
        character(len=1), intent(in) :: c
        integer :: next
        if (c == '.') then
            next = leading_dot
        else if (is_digit(c)) then
            next = integer_part
        else
            next = err
        end if
    end function

    function from_leading_dot(c) result(next)
        character(len=1), intent(in) :: c
        integer :: next
        if (is_digit(c)) then
            next = fraction
        else
            next = err
        end if
    end function

    function from_integer_part(c) result(next)
        character(len=1), intent(in) :: c
        integer :: next
        if (is_digit(c)) then
            next = integer_part
        else if (c == '.') then
            next = fraction
        else
            next = err
        end if
    end function

    function from_fraction(c) result(next)
        character(len=1), intent(in) :: c
        integer :: next
        if (is_digit(c)) then
            next = fraction
        else
            next = err
        end if
    end function

    logical function is_digit(c)
        character(len=1), intent(in) :: c
        is_digit = index('0123456789', c) > 0
    end function

    logical function is_real_literal(str)
        character(len=*), intent(in) :: str ! Must be left-adjusted on entry

        type :: transition
            procedure(from_start), pointer, nopass :: next => null()
        end type

        ! Static dispatch table, one row per state
        type(transition), parameter :: table(4) = [ &
            transition(from_start), &
            transition(from_leading_dot), &
            transition(from_integer_part), &
            transition(from_fraction)]

        ! Accepting (final) states of the automaton
        logical, parameter :: accepting(0:4) = &
            [.false., .false., .false., .true., .true.]

        integer :: i, s

        s = start
        do i = 1, len_trim(str)
            s = table(s)%next(str(i:i))
            if (s == err) exit
        end do
        is_real_literal = accepting(s)
    end function

end module

program test_real_literals
use real_literals, only: is_real_literal
implicit none
print *, is_real_literal("42.0")
print *, is_real_literal("3.14159")
print *, is_real_literal(".279")
print *, is_real_literal("31.")
print *, is_real_literal("ABC")
print *, is_real_literal("987654321")
print *, is_real_literal(".")
end program
