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
      able to prove after the assignment to next x that k is in the keys of x).
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
      program to verify.
* Now, moving on to sorted\_insert.dryad.c
  - The pre/post conditions are straightforward.
  - There are 4 basic blocks: 1. x = nil, 2. k > key x before recursive call,
    3. full k > key x case 4. k <= key x
  - Basics blocks 1, 2, and 4 all verify, but basic block 3 does not. I'm not
    that surprised, I suspect it will need some sort of lemma.
  - I'm able to verify the piece of the post condition about the keys, so the
    issue is clearly about saying that ret is Sorted.
  - The lemma I add is that if (Keys l1) = (SetAdd (Keys l2) k) then
    (Min l1) = (Min l2) or k, and the program is then able to verify
* Next, let's try quick\_sort.dryad.c, I'll immediately note that the program
  on the VCDryad examples page uses a loop for the partitioning piece, but I'll
  use another recursive function for this instead.
  - The base code has a statement that the keys of lpt are all less than or
    equal to the pivot and that all the keys of rpt are greater than or equal
    to the pivot. Since we don't have the ability to directly express that in
    Frame Logic, I'll use Min and a similarly defined Max.
  - I've defined a partition function, following along very similarly with its
    pre/post conditions to the loop invariant in the original
  - I've also decided to define the concat\_sorted function, and actually to
    have it use the fact that Max t1 <= Min t2 to speed up the concat (we only
    need to traverse to the end of t1)
  - There are going to be a bunch of issues of my formalization of everything
    and just my implementation, so I'm manually going through BB by BB
    (especially since currently bbverify gets run in glob order, not any
    sensible order). My first attempt, especially, caused a bunch of internal
    errors but I think some of that was issues in the code
  - Starting with contact\_sorted, the first 2 basic blocks verify and the 3rd
    does not (after nearly 10 minutes it finally fails). It seems likely that
    we need two lemmas: first, the previous lemma that the min of merging two
    lists is the min of their mins. Secondly, we need some lemma that says
    that Min l <= Max l. After some quick experiments, it turns out that only
    this second lemma is needed (and verification works faster with only it)

Thursday, April 13, 2023
* I was noticing some issues where things that I didn't expect to verify were
  being verified and there seemed actually to be bugs, but I realized that the
  lemma I introduced was was, I have modified it so that that if x is a list
  and non-nil then Min x <= Max x. I decided to also add the previous lemma
  about min of two merged lists and a similar one about the max of such lists.
  - That was running trying to verify BB 3 for over an hour and didn't manage
    it, so I'm going to go back and analyze what it is and isn't able to prove
    without these lemmas
  - The first issue I run into is that after the recursive call it is unable
    to verify that t1 not in the support of tmp (the return from the recursive
    call). It is also not able to prove that the key of t1 (the list we're
    walking through) is less than the min of tmp. Both of these need to be
    solved to prove the return value is a sorted list.
  - Going to try bringing back a lemma that notes that if we have three lists
    l1, l2, and l3 and the keys of l3 are the union of the keys of l1 and l2
    and Min l1 <= Min l2, then Min l3 = Min l1. In theory, I think this should
    be sufficient to prove (key t1) <= (Min tmp). We also need to add a lemma
    that If Max x <= Min y then Min x <= Min y, and then that part can be
    verified.
  - It seems to me that the thing we need to change to prove the support piece
    is that the two input lists are disjoint (i.e. have disjoint supports)
  - It is now saying that t1 is not a member of the support of tmp, which I
    didn't expect since I haven't added anything relating to support... It is
    able to verify contradictions so that must mean the lemmas are inconsistant
  - So, the lemma (Max x <= Min y) => (Min x <= Min y) is, on its own,
    contradictory apparently. I'm assuming the issue has to do with empty lists.
    After a bunch of experiments, I've settled on two lemmas that allows it
    to verify that (key t1) <= (Min tmp). The first is that if x is not nil
    and Max x <= Min y then Min x <= Min y. The second is then the lemma that
    if some list z's keys is the union of the keys of x and y then the min of
    z is either the min of x or the min y of (whichever is smaller). These
    lemmas seem to be consistant and allow the system to verify
    (key t1) <= (Min tmp).
  - So, the next (hopefully last) piece to prove is that t1 is not a member of
    the support of tmp. I'm going to try to check that this is the last thing
    we need by adding an assumption of it right after the function call and
    seeing if the final post condition will verify (it won't).
* Simultaneously to working on Quick Sort, I'm also going to start working on
  some DLL examples, specifically append and insert-back
  - Here, I wrote the definition of DLL by hand, following that in the dryad
    file and basing it also loosely on how the List recursive definition was
    defined in the examples.
  - I start with the file `dll_tests.fsl` which just shows an attempt to
    construct some doubly-linked lists to make sure that the definitions seem
    to work at least vaguely.
  - Then, working on `dll_insert_back.fsl` based on `dll-insert-back.dryad.c`.
    On the first attempt, BB 1 and 2 verify automatically but the third one
    (which is the full case where x =/= nil) does not.

Friday, April 14, 2023
* Adding a lemma about (DLL x) => (= (Sp (DLL x)) (Sp (Keys x))), like we've
  had elsewhere still does not allow BB 3 to verify (this is dll\_insert\_back)
  but it does fail to verify much quicker (4s instead of 33s).
  - Without the lemma, however, it is not able to verify that x is not a member
    of the support of (DLL tmp), directly after the function call.
  - The assignment to prev tmp seems to break the ability to prove the
    properties that will be necessary to prove x is a DLL.
  - It is no longer able to prove tmp is a DLL. Somehow it is no longer able to
    verify that (prev (next tmp)) = tmp. However, before the assignment it is
    able to prove that (next tmp) =/= tmp and is still able to verify this
    after the assignment to prev tmp.
  - For some reason, the post condition cannot be verified, but if I add
    (DLL (next (next ret))) to the and in the post condition, and it is able to
    verify it.
  - If I add an assume right before the return and just assume
    (DLL (next (next ret))) then everything is able to verify automatically.

Saturday, April 15, 2023
* Based on advice from Madhu and Adithya, adding the term (next (next ret))
  to the post condition so that it is instantiated and explored in the
  verification. After other experiments, settled on
    `(ite True True (= (next (next ret)) (next (next ret))))`
  just to make sure the term in included, but this is clearly a tautology.
  The program is now able to be verified entirely.
* Picking a slightly more complicated (from the conditions at least) example
  using doubly-linked lists, I'm using dll-mid-delete.dryad.c.
  - Just going to automatically add a RevDLL and RevKeys support lemma
  - BB 4 (v = nil and u = nil) automatically verifies, but the others do not,
    immediate thoughts are that it must have to do with the supports.
  - Exploring BB 3 (where v = nil and u =/= nil), the issue (after the
    assignment to next u) is not proving RevDLL u, but proving that the RevKeys
    of u is still the same.
    + My definition of RevDLL was wrong, and now its not able to prove RevDLL u
  - It is able to prove that prev(u) is a RevDLL.
  - It is able to prove that prev(u) = nil or next(prev(u)) = u
  - Another weird situation where it can prove u is a RevDLL iff we include
    that prev(u) is a RevDLL.
  - Adding (RevDLL (prev u)) to the final post condition, it is able to verify
    it as an UnsupportedPost, but not as RelaxedPost or Post.
    + This is resolved by adding to the precondition that p is not in the
      support of either u or v.
  - Adding that p is no in the support of u or v and a tautology involving
    (prev u) to the post condition, then BB 3 and 4 can verify.
  - Just assuming a similar issue, going to add a tautology involving (next v)
    now BB 2, 3, and 4 all can verify.
  - In BB 1, after the assignment to prev(v) it can prove v is a DLL, but not
    that u is a RevDLL. I'm assuming this has to do with support again. Adding
    an assumption that v is not in the support of u then it is able to prove
    that u is a RevDLL
  - After the assignment to (next u) it is not able to verify that RevDLL u,
    but adding that u is not in the support of v allows the verification. And,
    it then the post condition for the BB follows.
  - Adding these to the pre-condition, all four basic blocks verify
* Having verified 2 DLL programs, I'm going to move on to circular lists, I'll
  do delete back and insert front.
  - The definitions of circular lists given in the VCDryad examples are very
    limited, they don't state the circular list condition explicitly or say
    anything about the keys. I'm trying to implement conditions that are more
    detailed.
    + I implement Circ to define circular lists by saying that nil is a
      circular list and a non-nil is x a circular list if next(x) reaches x
      by a chain of x.
    + Similarly to this, I can define the set of keys for a circular list.
  - For insert front, had to add a case for x = nil, and this case verifies
    immediately. The second BB (non nil x), verification is running for a long
    time (it was only 15 minutes before I killed it, but I wanted to analyze
    it more in depth).
  - The assignment to key(ret) seems to break the ability to verify
    Lseg(tmp, x)

Sunday, April 16, 2023
* Spending a good deal of time trying to figure out how to express circular
  lists in a way that lets insert work.
  - I decided to try using a version where the node to insert is provided so
    that we don't have to deal with the alloc, which seemed like it may have
    been an issue yesterday.
  - Still having issues with the assignment to next(x), which suggests that the
    system can't prove that changing next(x) which has to be support related.
  - After some experiments, found I can just say that x is not an element of
    the support of Lseg(next(x), x)
  - Again, I'm finding that I need a tautology involving next(next(ret))
  - Added a lemma about the relation of the support of Lseg and CKys and now
    both BB can verify.
  - Trying to use this as a helper function, though, still the verification
    still won't work, specifically it can verify the post condition as a
    RelaxedPost, but not as a full Post, so the issue has to do with support.

Monday, April 17, 2023
* For some reason using the insert\_node as a helper didn't work, but just
  merging them together into a single function does work and the program is
  able to verify.
* I don't find the formalization of delete\_back very good, so actually going
  to skip that (at least for now).
* Moving on to binary search trees, I'm going to do insert, delete, and find.
  Starting with find as it is the shortest and appears simplest.
  - Going to define Min/Max functions like in Sorted to allow us to express the
    sorting property in BST (the definitions in VCDryad use set operations that
    don't exist in FL).
  - Also stating the correctness for find as the iff I used previously with
    find.
  - First run at verification verifies BB 1 (x = nil), BB 2 (key(x) = k), BB 3
    (pre-condition of recursive call on left(x)), and BB 5 (pre-condition of
    recursive call on right(x)). BB 4/6 (full cases in left/right recurse) fail
    + My assumption is that it can't verify that k is not in the other subtree.
  - I'm going to add the same lemma I used in the optimized sorted find, with a
    version for max as well.
  - 4 and 6 are still failing to verify, going to look into 4 in more detail.
    + The issue in 4 actually seems to be the problem about needing a certain
      term, specifically it appears to be right(x) here.
    + I'm going to assume the same issue is appearing in BB 6 and will add left
      and right of x to the post condition in a tautology
  - It now fully verifies.
* Moving next to insert
  - I'm going to implement a slightly different version than theirs, I don't
    particularly like the condition that k not be in the tree already
  - Again, we have 6 BBs: 1 is x = nil, 2 is k = key(x), 3 is checking the
    precondition on the recursive call on left(x), 4 is the full case where we
    go into left(x), 5 is the precondition for the recursion on right(x), and
    6 is the full case with right(x)
    + BBs 1, 2, 3, and 5 all verify immediately (I killed BB 4 after 5 minutes
      and didn't give 6 a chance)
    + My guess is that we need lemmas like I had in sorted insert saying giving
      properties about lists who's keys are the same as some other list with
      one additional element added
  - After adding that lemma, it still isn't verifying BB 4 in a reasonable
    length of time.
  - The issue seems to be the assignment to left(x), which suggests the issue
    is support; specifically I found that it must have been the support of
    Min/Max, so I'm going to add lemmas similar to the support lemma for keys,
    though in this case the support for Min/Max is a subset of the support for
    BST
  - It seems to also need left(ret) and right(ret) to be mentioned in the post
    condition. Takes 1.5 minutes to varify (as Supportless) 

Tuesday, April 18, 2023
* I'm going back to quick sort just because I really would like to actually
  have it verified.
  - Of concat\_sorted, BB 1 (t1 = nil) and BB 2 (pre-condition on recursive
    call) verify quickly. BB 3 seems not to.
  - BB 3 needs to strengthen the pre-condition to mention that t1 is not in
    the support of Sorted(t2), and add lemmas about the support of Min/Max and
    that they're equal with the support of Sorted
  - However, now BB 2 won't verify presumably because it doesn't recognize that
    next(t1) is not in the support of Sorted(t2) either, so going to change
    it to be that the intersection of their supports is empty.
  - All 3 BBs in concat sorted now verify.
  - Moving on to partition, BB 4 (cur = nil) verifies
  - BB 5 fails, the issue is the assignment to next(cur) which because of the
    supports it can't prove doesn't affect lpt/rpt. Adding to the precondition
    that the intersection of the supports of cur/lpt/rpt (pairwise) is empty.
  - This allows BB 5 and BB 6 to verify. BB 7 can verify as a RelaxedPost
    condition but not as a full Post, meaning the issue must be that it can't
    prove something is still part of the support

Thursday, April 20, 2023
* I have everything in quick sort verified except for BB 7/8, which are issues
  with the support.
  - One thing to note here, I had weird issued because I had assigned next x
    to nil in the main function, removing this (it had no real purpose) made
    several things suddenly be able to be verified.
* I was going to move on to red-black trees, but I have a bunch of questions
  about the implementation in VCDryad, and I want to check a copy of Cormen
  or maybe even a functional language implementation of Red-Black trees.
* Instead, going to do 2 from treaps: insert and find.
* Again, need to use Min/Max and MaxPrio rather than set operations. No MinPrio
  since the priorities are in heap-order
  - Starting with treap find, after adding lemmas that the support of keys,
    priorities, MinKey, MaxKey, and MaxPrio are all equal to the support of
    Treap, everything but the cases where we only search have the tree go
    through. Clearly, we need the appropriate lemmas
  - Also needed to add mentions of left(x) and right(x) to the post condition
  - Note: My post-condition is slightly more powerful than the VCDryad one,
    since I'm saying x is still a treap and has the same keys as before, it's
    a pretty trivial addition, but worth mentioning I think
