Monday, April 3, 2023
* After reading the documentation, I decided to write a version of a merge
  function (like is used as part of merge-sort). I noticed several other
  benchmarks that use sorted lists, but they define the sorting in relation to
  the minimum of the list, rather than just being smaller than the next value
  (where of course the tail should also be sorted).
  - In the first attempt to verify it, it identified 6 BBs:
    1. not proven ( 0.792 seconds)
      + Case of x = nil
    2. not proven ( 0.749 seconds)
      + Case of y = nil
    3. is valid   ( 0.856 seconds)
      + Case up to the recursive call when key x <= key y
    4. not proven (22.487 seconds)
      + Full case when key x <= key y
    5. is valid   ( 0.863 seconds)
      + Case up to the recursive call when key y < key x
    6. not proven ( 4.513 seconds)
      + Full case when key y < key x
  - On the next attempt, I modify the definition of Sorted to match what's used
    in the existing examples on the thought that it may be a more amenable
    definition for the automated verification. I also added the lemmas I saw in
    the other benchmarks which may have also helped
    1. is valid   (0.881 s)
    2. is valid   (0.880 s)
    3. is valid   (0.995 s)
    4. not proven (4.259 s)
    5. is valid   (1.014 s)
    6. not proven (5.552 s)
    So we can see that it does much better this time in that it is able to
    verify the base cases, but still fails on the recursive cases.
    + My thought is that we need something here that will tell us that the
      element that we're putting first is smaller than the min of the result of
      the recursive call
  - After some experimenting with assumptions, even assuming the post condition
    right before the return in BB 4 still doesn't cause verification to work,
    which suggests this may have something to do with the support if I
    understand the meaning of of the post conditions correctly. I confirm this
    by taking the file generated for that basic block and changing it to a
    SupportlessPost condition, which with the assumption of the post condition
    makes the verification go through very quickly, but when I remove the
    assumption it still fails to verify.
  - Playing around with it more, the issue seems to be that our pre conditions
    don't say anything about the support of x and y being distinct meaning that
    the recursive call could be messing with x, this still doesn't make BB 4/6
    verifiable, but that's not unexpected at this point.
