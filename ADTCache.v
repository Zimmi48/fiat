Require Import Common Computation ADT Ensembles ADTRefinement.

Generalizable All Variables.
Set Implicit Arguments.

  Open Scope comp_scope.

  Section addCache.

  (* A cache simply adds a new value to an ADT's representation [rep]. *)

    Variable rep : Type.
    Variable cacheTyp : Type.

    Record cachedRep := cOb
      { origRep : rep;
        cachedVal : cacheTyp }.

    (* There are two main ways of augmenting an ADT with a cache. *)

    (* To add a cache, we update an ADT's mutators to include cached values.
       We first running the old mutators
       to obtain the original mutated representation [or], then we add
       Pick implementation of the [cacheSpec] specification to the result. *)

    Definition AddCacheEntry
               {MutatorIndex}
               (MutatorMethods : MutatorIndex -> mutatorMethodType rep)
               (cacheSpec : rep -> nat -> cacheTyp -> Prop)
               idx r n :=
      or <- MutatorMethods idx (origRep r) n;
      cv <- Pick (cacheSpec or n);
      ret {| origRep := or;
             cachedVal := cv |}.

    Variable repInv : Ensemble rep.

    Definition ValidCacheInv 
               (cacheSpec : rep -> nat -> cacheTyp -> Prop)
               (n : nat) (r : cachedRep) :=
      repInv (origRep r) /\ cacheSpec (origRep r) n (cachedVal r).

    Lemma AddCacheEntryInv {MutatorIndex}:
      forall
        (MutatorMethods : MutatorIndex -> mutatorMethodType rep)
        (MutatorMethodsInv :
           forall (idx : MutatorIndex) (r : rep) (n : nat),
             repInv r -> computational_inv repInv (MutatorMethods idx r n))
        (cacheSpec : rep -> nat -> cacheTyp -> Prop)
        (idx : MutatorIndex)
        (r : cachedRep) (n : nat),
        ValidCacheInv cacheSpec n r ->
        computational_inv (ValidCacheInv cacheSpec n)
                          (AddCacheEntry MutatorMethods cacheSpec idx r n).
    Proof.
      unfold AddCacheEntry, ValidCacheInv; simpl; intros.
      inversion_by computes_to_inv; subst; eauto.
    Qed.

    End addCache.

  Definition addCachedValue {cacheTyp} adt (cacheSpec : Rep adt -> nat -> cacheTyp -> Prop)
  : ADT :=
    {| Rep := cachedRep (Rep adt) cacheTyp;
       RepInv r := exists n, ValidCacheInv (RepInv adt) cacheSpec n r;
       ObserverIndex := ObserverIndex adt;
       MutatorIndex := MutatorIndex adt;
       ObserverMethods idx r := ObserverMethods adt idx (origRep r);
       MutatorMethods idx r n :=
         AddCacheEntry (MutatorMethods adt) cacheSpec idx r n;
       MutatorMethodsInv := AddCacheEntryInv (MutatorMethodsInv adt) (cacheSpec := cacheSpec) |}.

  Theorem refinesAddCachedValue
          {cacheTyp}
          adt
          (cacheSpec : Rep adt -> cacheTyp -> Prop)
  : refineADT adt (addCachedValue adt cacheSpec).
  Proof.
    unfold addCachedValue, ValidCacheInv; destruct adt.
    econstructor 1 with
    (abs := fun r : cachedRep Rep cacheTyp =>  ret (origRep r))
      (mutatorMap := @id MutatorIndex) (* Have to specify MutatorIndex in order to
                                        unify- 8.5 might fix this? *)
      (observerMap := @id ObserverIndex); simpl; unfold id; unfold AddCacheEntry;
    intros; autorewrite with refine_monad.
    - unfold refine; intros; inversion_by computes_to_inv; subst; eauto.
    - reflexivity.
    - inversion_by computes_to_inv; subst; eauto.
  Qed.

  Definition replaceObserverCache adt
             (ObserverIndex_eq : forall idx idx' : ObserverIndex adt, {idx = idx'} + {idx <> idx'})
             (f : Rep adt -> nat -> Comp nat)
             (cachedIndex : ObserverIndex adt)
  : ADT :=
    {| Rep := Rep adt;
       RepInv := RepInv adt;
       ObserverIndex := ObserverIndex adt;
       MutatorIndex := MutatorIndex adt;
       ObserverMethods idx :=
         if (ObserverIndex_eq idx cachedIndex) then
           f
         else
         ObserverMethods adt idx;
       MutatorMethods := MutatorMethods adt;
       MutatorMethodsInv := MutatorMethodsInv adt |}.

  Lemma refinesReplaceObserverCache
             adt
             (ObserverIndex_eq : forall idx idx' : ObserverIndex adt, {idx = idx'} + {idx <> idx'})
             (f : Rep adt -> nat -> Comp nat)
             (cachedIndex : ObserverIndex adt)
             (refines_f : forall r n, RepInv adt r -> refine (ObserverMethods adt cachedIndex r n) (f r n))
  : refineADT adt (replaceObserverCache adt ObserverIndex_eq f cachedIndex).
  Proof.
    unfold replaceObserverCache; destruct adt; simpl.
    econstructor 1 with (abs := fun r : Rep => ret r)
      (mutatorMap := @id MutatorIndex) (* Have to specify MutatorIndex in order to
                                        unify- 8.5 might fix this? *)
      (observerMap := @id ObserverIndex); simpl in *|-*; unfold id; intros;
    autorewrite with refine_monad.
    - reflexivity.
    - find_if_inside; subst; [eauto | reflexivity].
    - inversion_by computes_to_inv; subst; eauto.
  Qed.

  Lemma refinesReplaceAddCache
        adt
        (ObserverIndex_eq : forall idx idx' : ObserverIndex adt, {idx = idx'} + {idx <> idx'})
        (cacheSpec : Rep adt -> nat -> nat -> Prop)
        (cachedIndex : ObserverIndex adt)
        (refines_f : forall r n v, cacheSpec r n v ->
                                   refine (ObserverMethods adt cachedIndex r n) (ret v))
  : refineADT adt
              (replaceObserverCache (addCachedValue adt cacheSpec)
                                    ObserverIndex_eq (fun r _ => ret (cachedVal r)) cachedIndex).
  Proof.
    etransitivity. (* Example of where we can't rewrite? *)
    eapply refinesAddCachedValue.
    eapply refinesReplaceObserverCache.
    unfold addCachedValue, ValidCacheInv; simpl; intuition.
  Qed.