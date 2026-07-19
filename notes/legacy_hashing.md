
Using a pointer function for hashing

There is an old little known Fortran book that goes by the title

A. Colin Day, Fortran techniques with special reference to non-numerical applications,
Cambridge University Press, 1972

Colin shares the following snippet (page 39),

```fortran
      DIMENSION VAL(1000), IND(1000)
      DATA IND /1000 * 0/
      ...
C HASH I TO AN INITIAL VALUE WITHIN THE TABLE
      IHS = MOD(I, 1000) + 1
      MARK = 0
C IS THE ITEM STORED AT THIS PLACE
    1 IF (IND(IHS) .EQ. I) GO TO 10
C IS THIS PLACE EMPTY
      IF (IND(IHS) .EQ. 0) GO TO 20
C STEP ON THROUGH THE TABLE
      IHS = IHS + 1
      IF (IHS .LE. 1000) GO TO 1
      IF (MARK .NE. 0) GO TO 99
      MARK = 1
      IHS = 1
      GO TO 1
```

Hashing with non-linear search

```fortran
      DIMENSION VAL(991), IND(991)
      DATA IND/991*0/
      ...
C HASH I TO AN INITIAL VALUE WITHIN
C        THE TABLE
      IHS = MOD(I, 991) + 1
      INC = -991
C IS THE ITEM STORED AT THIS PLACE
C        IN THE TABLE
    1 IF (IND(IHS) .EQ. I) GO TO 10
C IF THIS PLACE EMPTY
      IF (IND(IHS) .EQ. 0) GO TO 20
C STEP ON THROUGH THE TABLE
      INC = INC + 2
      IHS = IHS + IABS(INC)
      IF (IHS .GT. 991) IHG = IHS - 991
      IF (INF .LT. 991) GO TO 1
   99 CONTINUE
```


2) Write and test a set of subroutines to access a sparse two-dimensional array
   1000 x 1000 using hash table techniques. (The two subscripts may be packed in one integer cell)

3) Write a program to read in a Fortran program and print out a message whenever
   a label is found which has been used before on another statement.
   (When you read a new card, test first for a comment, then for a continuation line.
   If the card is neither of these, look for a label. Remember to clear your store
   of labels whenver you find an END line. The END statement may not be continued.)

Could this be used to write a GOTO relabeler? We can identify labels based on the
columns they are in. And we can attempt to identify statements which support labels (GOTO, DO)
This was a common tool in the old days of Fortran development.
