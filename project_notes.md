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

Tuesday, April 4, 2023
* I now combine the two previous programs and a small new program to write
  merge-sort. It takes quite a while to verify, specifically BB 17 (which is
  the case that involves the recursive call and then the merge operation and
  return) takes 37 minutes and fails to verify.
  - I'm going to attempt to verify just that basic block with a weaker
    condition, specifically we'll have it ignore support and only ask it to
    show that the resulting list is sorted. Then, I'll add back that the list
    should have the same keys as the original list.
    + The first attempt (just that ret is sorted) is verified pretty much
      instantly
    + Adding the property about the keys makes verification take a little
      longer, but it pretty quickly verifies it as well, meaning that the issue
      is definitely related to supports.
    + I next try it with a RelaxedPost rather than SupportlessPost to see what
      happens this way, and it agains reports validity, which means that the
      issue must be some part of the support that is not accounted for.
    + Based on the other lemmas present, I decided to add two extra lemmas to
      the file, one saying that for a Sorted list, the Support of it as a List
      and as Sorted is the same, and one saying that for a List, the support of
      the Keys and the List are the same. It appears to me that this second one
      was essential as it is able to verify quickly when that is included but
      not verify (at least quickly) when it is not.
  - With the added lemma, the program fully verifies:
    
    BB  1. is valid ( 1.115 s)
    + Merge function, x is nil case

    BB  2. is valid ( 1.118 s)
    + Merge function, y is nil case

    BB  3. is valid ( 1.632 s)
    + Merge function, key x <= key y case before recursive call

    BB  4. is valid (13.863 s)
    + Merge function, key x <= key y full case

    BB  5. is valid ( 1.780 s)
    + Merge function, key y <= key x case before recursive call

    BB  6. is valid (15.208 s)
    + Merge function, key y <= key x full case

    BB  7. is valid ( 1.503 s)
    + Split function, x is nil case

    BB  8. is valid ( 2.457 s)
    + Split function, next x is nil case

    BB  9. is valid ( 5.073 s)
    + Split function, x at least 2 elements case before the recursive call

    BB 10. is valid (29.380 s)
    + Split function, x at least 2 elements, full case

    BB 11. is valid ( 0.879 s)
    + Sort function, x is nill case

    BB 12. is valid ( 1.270 s)
    + Sort function, x has one element case

    BB 13. is valid ( 0.464 s)
    + Sort function, x at least 2 elements, up until split call

    BB 14. is valid ( 0.521 s)
    + Sort function, x at least 2 elements, up until first recursive call

    BB 15. is valid ( 9.623 s)
    + Sort function, x at least 2 elements, up until second recursive call

    BB 16. is valid (19.401 s)
    + Sort function, x at least 2 elements, up until merge call

    BB 17. is valid (38.756 s)
    + Sort function, x at least 2 elements, full case

Saturday, April 8, 2023
* I downloaded the sll-find.dryad.c file from VCDryad examples to begin porting
  some benchmarks from that dataset into FL.
  - The definitions of sll and keys in the VCDryad code are very similar to
    those from other sll examples in FL, so I'm simply going to keep using
    those (List and Keys).
  - The post condition I used is based on the one from the example, but we
    break the <=> into a => and a <= case.
  - I put the condition that Keys x = oldkeysx into the precondition because I
    think I prefer that style to the assumption one I had previously been using
  - The verification went through immediately (all 4 basic blocks are valid, in
    less than 3 seconds total)
* I next downloaded sll-insert-back.dryad.c
  - Again, going to use the previous definition of List and Keys
  - Going to need to use alloc since this requires malloc in the original code
  - In my first attempt, BB 1 and 3 fail to verify (1 is x = nil case, 3 is
    everything in the recursive case)
    + Continue with the procedure I've been using, of weakening the post
      condition on a basic block on its own to see what issues are preventing
      the verification
    + For BB 1, I simply have to add an assumption that ret (which is alloc'd)
      is not nil; I saw this in some other code and in the VCDryad code
    + For BB 3, changing it to a SupportlessPost doesn't make it verify, and is
      not even able to verify that ret is a list. When I assign next x = tmp,
      that breaks its ability to verify even just that tmp is a list. The issue
      it seems must be that it is unable to verify (after the recursive call)
      that x isn't in the support of tmp (which indeed I tested and it wasn't
      able to verify that).
    + I added an assumption after the call to say that x is not in the support
      of tmp, and then after the assignment to next x, it is able to verify
      a SupportlessPost that List ret. It is not able to prove this for a
      RelaxedPost, or anything about the keys of ret (and in fact it is not
      able to prove after the assignment to next x that k is in the keys of x.
      It seems to think the assignment to next x may change the keys of tmp.
    + The whole thing is fixed by adding the lemma about SPKeys = SPList, and
      it now verifies is less than 3.5 seconds.

Sunday, April 9, 2023
* Given that I implemented find and insert on singly linked lists yesterday, I
  decide to attempt to implement and verify find and insert on sorted lists. I
  start with sorted\_find.dryad.c
  - I'm going to continue using the definition of Sorted from within the FOSSIL
    repo, the definition in the file relies on a `lt-set` operation that I
    don't believe exists in this tool.
  - I've specified the post condition basically the same as in that file and
    just added a (Keys x) = oldkeysx precondition.
  - There are 4 basic blocks (x = nil, key x = k, recursive case before the
    recursive call, and the full recursive case). All verify immediately.
  - NOTE: This is a really bad implementation of find on a sorted list, there's
    no reason to keep searching once (key x) > k. I'm going to try to implement
    a version like that in sorted\_find\_opt.fsl.
    + Everything but the extra basic block verifies immediately, but not the
      extra basic block.
    + I'm going to try adding a simple lemma, that if k > Min x then k is not
      an element of Keys x.
    + I'm not able to write the lemma I want, at least on my first attempt,
      because I want to write something about k which has type Int, so I'm
      getting an error about 'variables [...] must be of the foreground sort'
    + Just ommiting k from the binding appears to resolve this and allows the
      program to verify, but it turns out that this is definitely some kind of
      bug because I'm able to get it to verify contradictions (like k in
      oldkeysx and k not in oldkeysx)
    + Going to email Adithya about if there's a way to write a lemma involving
      an Int, and mention that there seems to be some sort of bug with using
      unbound variables in a lemma.
