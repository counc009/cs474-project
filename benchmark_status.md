# Benchmark Status
* Singly-Linked Lists
  - Insert Back (`verified/sll_insert_back.fsl`): fully verifies
  - Find (`verified/sll_find.fsl`): fully verifies
* Sorted (Singly-Linked) Lists
  - Find (`verified/sorted_find.fsl`): fully verifies; this version implements
    early exit (once the key at the head of the list is greater than the search
    key, stop) which differs from the version already in the repository.
* Sorting Algorithms (on Singly-Linked Lists)
  - Merge Sort (`verified/merge_sort.fsl`): fully verifies; note that since we
    are using lists rather than arrays, the split part is implemented by a
    recursive function which splits the list in two by taking the even index
    elements (0, 2, 4, ...) into one list and the odds into another.
  - Quick Sort (`quick_sort.fsl`): does not verify due to a known bug. The
    implementation has 3 functions
    + Concat Sorted: fully verifies; takes two sorted (disjoint) lists where
      the maximum element of the first is no larger than the minimum element of
      the second and combines them into a single sorted list. This is composed
      of basic blocks 1-3
    + Partition: This performs the partitioning to separate elements less than
      the key from those greater than the key; the implementation is tail
      recursive to match a more traditional iterative implementation. This
      function is basic blocks 4-8, basic blocks 4-6 verify fine but 7-8 do
      not verify due to a known bug
    + Quick Sort: fully verifies; performs the quick sort algorithm, using the
      first element of the list as the pivot, partitioning, quick sorting the
      sub-lists (based on the VCDryad code, it always sorts the right hand side
      but doesn't sort the left if it is empty). This function is basic blocks
      9-15
* Doubly-Linked Lists
  - Insert Back (`verified/dll_insert_back.fsl`): fully verifies
  - Mid Delete (`verified/dll_mid_delete.fsl`): fully verifies
* Circular List
  - Insert Front (`verified/cl_insert_front.fsl`): fully verifies; my version
    uses much stronger conditions than the version in the repository already,
    specifically that version does not mention keys at all while mine does.
  - Find (`verified/cl_find.fsl`): fully verifies; this program is not in the
    VCDryad examples because their specification does not mention keys, but
    mine supports it so I'm including it
* Binary Search Tree
  - Find (`verified/bst_find.fsl`): fully verifies; note that this version is
    basically the same as the one in the repository already except that it is
    written as a single program rather than separate basic blocks
  - Insert (`verified/bst_insert.fsl`): fully verifies; this is the standard
    BST insert algorithm, though one change from the algorithm in VCDryad, I
    believe, is that it does not require the key to be inserted not already be
    in the tree.
* Red-Black Tree
  - Insert (`rbt_insert.fsl`): all but BBs 5, 6, 9, 10 verify; in trying to
    debug why these don't verify (mostly on BB 5), eventually trying to verify
    some property just runs forever (I've let things run at least a day before
    and they haven't finished)
* Binary Search Tree To Sorted List
  - `tree2list.fsl`: fails to verify; based on the VCDryad one, returning a
    sorted list of the keys in the tree; I have had to move the insert into the
    list into a separate function, it seems like the alloc that was involved
    caused issues with getting it to verify properly. Because of similar issues
    with the free (the program in VCDryad frees the entire tree) my version
    instead does not change the tree and this is part of the post-condition.
    The program as written has 6 basic blocks, all of which but the last
    succeed, the last one will verify as a relaxed post condition (takes about
    an hour), but not as a fully post condition though it doesn't fail it
    simply runs for days on end (so I suspect this is the same bug as in quick
    sort)
* Treaps
  - Find (`verified/treap_find.fsl`): fully verifies
  - Insert (`treap_insert.fsl`): this program is based on the VCDryad version
    and contains 7 basic blocks. All but 4 and 7 verify (4 and 7 are the
    cases where we perform rotations to move the priorities). I have tried
    adding assumptions (in BB 4 currently though similar ones would be needed
    in BB 7) to help get it to verify, but again I've encountered that
    verification can run for hours, making it difficult to determine what
    changes to apply or assumptions to add
