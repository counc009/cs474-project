Monday, April 3, 2023
* After reading the documentation, I decided to write a version of a merge
  function (like is used as part of merge-sort). I noticed several other
  benchmarks that use sorted lists, but they define the sorting in relation to
  the minimum of the list, rather than just being smaller than the next value
  (where of course the tail should also be sorted).
  - In the first attempt to verify it, it identified 6 BBs:

    BB 1. not proven ( 0.792 seconds)
      + Case of x = nil

    BB 2. not proven ( 0.749 seconds)
      + Case of y = nil

    BB 3. is valid   ( 0.856 seconds)
      + Case up to the recursive call when key x <= key y

    BB 4. not proven (22.487 seconds)
      + Full case when key x <= key y

    BB 5. is valid   ( 0.863 seconds)
      + Case up to the recursive call when key y < key x

    BB 6. not proven ( 4.513 seconds)
      + Full case when key y < key x
  - On the next attempt, I modify the definition of Sorted to match what's used
    in the existing examples on the thought that it may be a more amenable
    definition for the automated verification. I also added the lemmas I saw in
    the other benchmarks which may have also helped

    BB 1. is valid   (0.881 s)

    BB 2. is valid   (0.880 s)

    BB 3. is valid   (0.995 s)

    BB 4. not proven (4.259 s)

    BB 5. is valid   (1.014 s)

    BB 6. not proven (5.552 s)

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
  - Now, just going to add an assumption that (key x) <= (Min tmp) in BB 4 and
    a similar assumption in BB 6 to see what happens. It is now able to verify
    all of the basic blocks!
  - To try to remove just these assumptions, and instead fold things into
    obvious lemmas, I'm going to experiment to try to figure out what the tool
    is able to verify before the recursive call, specifically I'm curious if in
    BB 3 it can tell that (key x) <= (Min y)
    + Slightly surprisingly it is able to verify that, though it is obviously
      true.
  - I managed to remove the assumptions from the code by adding a lemma saying
    that if (key x) <= (Min l1) and (key x) <= (Min l2) and (Keys l3) =
    (SetUnion (Keys l1) (Keys l2)) then (key x) <= (Min l3), which is pretty
    obviously true, though this lemma significantly increased the verification
    time:
    1. is valid ( 3.087 s)
    2. is valid ( 2.973 s)
    3. is valid ( 7.072 s)
    4. is valid (88.357 s)
    5. is valid ( 6.682 s)
    6. is valid (83.593 s)
  - Just out of curiousity, I'm going to try some other lemmas to see how they
    impact performance and if the program is still able to be verified with
    them. By changing the lemma to be (Keys l3) = (SetUnion (Keys l1) (Keys l2)
    implies that if (Min l1) <= (Min l2) then (Min l3) = (Min l1) and otherwise
    (Min l3) = (Min l2) it's still able to verify the entire program and much
    faster:

    BB 1. is valid ( 1.263 s)

    BB 2. is valid ( 1.299 s)

    BB 3. is valid ( 1.996 s)

    BB 4. is valid (13.828 s)

    BB 5. is valid ( 2.364 s)

    BB 6. is valid (15.729 s)

    (Note, the time seems to vary from run to run, but the difference seems to
    maintain across several runs)
* Next, I implemented a singly-linked list split function which splits an sll
  into 2 lists. It took some effort to make sure that I was assigning things
  properly to split the list and get the support correct, but thinking through
  it it carefully and using the debug techniques I did earlier, this worked
  well, and the program is automatically verified.
