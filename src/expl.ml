(*******************************************************************)
(*     This is part of WhyMon, and it is distributed under the     *)
(*     terms of the GNU Lesser General Public License version 3    *)
(*           (see file LICENSE for more details)                   *)
(*                                                                 *)
(*  Copyright 2023:                                                *)
(*  Dmitriy Traytel (UCPH)                                         *)
(*  Leonardo Lima (UCPH)                                           *)
(*******************************************************************)

open Base
open Pred

module Fdeque = Core.Fdeque

module Part = struct

  (* TODO: Remove concrete type from signature file                *)
  (*       In order to do this, I must rewrite do_exists/do_forall *)
  type 'a t = ((Domain.t, Domain.comparator_witness) Setc.t * 'a) list

  let random_empty_set = Set.empty (module String)

  let trivial p = [(Setc.univ (module Domain), p)]

  let hd part = snd (List.hd_exn part)

  let map part f = List.map part ~f:(fun (s, p) -> (s, f p))

  let fold_left part init f = List.fold_left part ~init:init ~f:(fun acc (_, p) -> f acc p)

  let filter part f = List.filter part ~f:(fun (_, p) -> f p)

  let exists part f = List.exists part ~f:(fun (_, p) -> f p)

  let for_all part f = List.for_all part ~f:(fun (_, p) -> f p)

  let values part = List.map part ~f:(fun (_, p) -> p)

  let rec tabulate ds f z =
    (Setc.Complement ds, z) ::
      (Set.fold ds ~init:[] ~f:(fun acc d -> (Setc.Finite (Set.of_list (module Domain) [d]), f d) :: acc))

  let rec merge2 f part1 part2 = match part1, part2 with
    | [], _ -> []
    | (sub1, v1) :: part1, part2 ->
       let part12 = List.filter_map part2
                      ~f:(fun (sub2, v2) ->
                        (if not (Setc.is_empty (Setc.inter sub1 sub2))
                         then Some (Setc.inter sub1 sub2, f v1 v2) else None)) in
       let part2not1 = List.filter_map part2
                         ~f:(fun (sub2, v2) ->
                           (if not (Setc.is_empty (Setc.diff sub2 sub1))
                            then Some (Setc.diff sub2 sub1, v2) else None)) in
       part12 @ (merge2 f part1 part2not1)

  let merge3 f part1 part2 part3 = match part1, part2, part3 with
    | [], _ , _
      | _ , [], _
      | _ , _ , [] -> raise (Invalid_argument "one of the partitions is empty")
    | part1, part2, part3 ->
       merge2 (fun pt3 f' -> f' pt3) part3 (merge2 f part1 part2)

  let split_prod part = (map part fst, map part snd)

  let split_list part =
    let subs = List.map part ~f:fst in
    let vs = List.map part ~f:snd in
    List.map (Option.value_exn (List.transpose vs)) ~f:(List.zip_exn subs)

  let rec el_to_string indent var f (sub, v) =
    Printf.sprintf "%s%s ∈ %s\n\n%s" indent (Term.value_to_string var) (Setc.to_string sub)
      (f (indent ^ (String.make 4 ' ')) v)

  let to_string indent var f = function
    | [] -> indent ^ "❮ · ❯"
    | [x] -> indent ^ "❮\n\n" ^ (el_to_string indent var f x) ^ "\n" ^ indent ^ "❯\n"
    | xs -> List.fold_left xs ~init:(indent ^ "❮\n\n")
              ~f:(fun s el -> s ^ (el_to_string indent var f el) ^ "\n") ^ indent ^ "❯\n"

end


module Proof = struct

  type sp = sp_ Hashcons.hash_consed
  and sp_ =
    | STT of int
    | SEqConst of int * string * Domain.t
    | SPred of int * string * Term.t list
    | SNeg of vp
    | SOrL of sp
    | SOrR of sp
    | SAnd of sp * sp
    | SImpL of vp
    | SImpR of sp
    | SIffSS of sp * sp
    | SIffVV of vp * vp
    | SExists of string * Domain.t * sp
    | SForall of string * (sp Part.t)
    | SPrev of sp
    | SNext of sp
    | SOnce of int * sp
    | SEventually of int * sp
    | SHistorically of int * int * sp Fdeque.t
    | SHistoricallyOut of int
    | SAlways of int * int * sp Fdeque.t
    | SSince of sp * sp Fdeque.t
    | SUntil of sp * sp Fdeque.t
  and vp = vp_ Hashcons.hash_consed
  and vp_ =
    | VFF of int
    | VEqConst of int * string * Domain.t
    | VPred of int * string * Term.t list
    | VNeg of sp
    | VOr of vp * vp
    | VAndL of vp
    | VAndR of vp
    | VImp of sp * vp
    | VIffSV of sp * vp
    | VIffVS of vp * sp
    | VExists of string * (vp Part.t)
    | VForall of string * Domain.t * vp
    | VPrev of vp
    | VPrev0
    | VPrevOutL of int
    | VPrevOutR of int
    | VNext of vp
    | VNextOutL of int
    | VNextOutR of int
    | VOnceOut of int
    | VOnce of int * int * vp Fdeque.t
    | VEventually of int * int * vp Fdeque.t
    | VHistorically of int * vp
    | VAlways of int * vp
    | VSinceOut of int
    | VSince of int * vp * vp Fdeque.t
    | VSinceInf of int * int * vp Fdeque.t
    | VUntil of int * vp * vp Fdeque.t
    | VUntilInf of int * int * vp Fdeque.t

  type t = S of sp | V of vp

  let m1 = Hashcons.create 271
  let m2 = Hashcons.create 271

  let hash x = x.Hashcons.hkey
  let head x = x.Hashcons.node

  let s_hash = function
    | STT tp -> Hashtbl.hash (2, tp)
    | SEqConst (tp, x, c) -> Hashtbl.hash (3, tp, x, c)
    | SPred (tp, r, terms) -> Hashtbl.hash (5, tp, r, terms)
    | SNeg vp -> Hashtbl.hash (7, vp)
    | SOrL sp1 -> Hashtbl.hash (11, sp1)
    | SOrR sp2 -> Hashtbl.hash (13, sp2)
    | SAnd (sp1, sp2) -> Hashtbl.hash (17, sp1, sp2)
    | SImpL vp1 -> Hashtbl.hash (19, vp1)
    | SImpR sp2 -> Hashtbl.hash (23, sp2)
    | SIffSS (sp1, sp2) -> Hashtbl.hash (29, sp1, sp2)
    | SIffVV (vp1, vp2) -> Hashtbl.hash (31, vp1, vp2)
    | SExists (x, d, sp) -> Hashtbl.hash (37, x, d, sp)
    | SForall (x, part) -> Hashtbl.hash (41, x, part)
    | SPrev sp -> Hashtbl.hash (43, sp)
    | SNext sp -> Hashtbl.hash (47, sp)
    | SOnce (tp, sp) -> Hashtbl.hash (53, tp, sp)
    | SEventually (tp, sp) -> Hashtbl.hash (59, tp, sp)
    | SHistorically (tp, ltp, sps) -> Hashtbl.hash (61, tp, ltp, sps)
    | SHistoricallyOut tp -> Hashtbl.hash (67, tp)
    | SAlways (tp, htp, sps) -> Hashtbl.hash (71, tp, htp, sps)
    | SSince (sp2, sp1s) -> Hashtbl.hash (73, sp2, sp1s)
    | SUntil (sp2, sp1s) -> Hashtbl.hash (79, sp2, sp1s)
  and v_hash = function
    | VFF tp -> Hashtbl.hash (83, tp)
    | VEqConst (tp, x, c) -> Hashtbl.hash (89, tp, x, c)
    | VPred (tp, r, terms) -> Hashtbl.hash (97, tp, r, terms)
    | VNeg sp -> Hashtbl.hash (101, sp)
    | VOr (vp1, vp2) -> Hashtbl.hash (103, vp1, vp2)
    | VAndL vp1 -> Hashtbl.hash (107, vp1)
    | VAndR vp2 -> Hashtbl.hash (109, vp2)
    | VImp (sp1, vp2) -> Hashtbl.hash (113, sp1, vp2)
    | VIffSV (sp1, vp2) -> Hashtbl.hash (127, sp1, vp2)
    | VIffVS (vp1, sp2) -> Hashtbl.hash (131, vp1, sp2)
    | VExists (x, part) -> Hashtbl.hash (137, x, part)
    | VForall (x, d, vp) -> Hashtbl.hash (139, x, d, vp)
    | VPrev vp -> Hashtbl.hash (149, vp)
    | VPrev0 -> Hashtbl.hash (151)
    | VPrevOutL tp -> Hashtbl.hash (157, tp)
    | VPrevOutR tp -> Hashtbl.hash (163, tp)
    | VNext vp -> Hashtbl.hash (167, vp)
    | VNextOutL tp -> Hashtbl.hash (173, tp)
    | VNextOutR tp -> Hashtbl.hash (179, tp)
    | VOnceOut tp -> Hashtbl.hash (181, tp)
    | VOnce (tp, ltp, vps) -> Hashtbl.hash (191, tp, ltp, vps)
    | VEventually (tp, htp, vps) -> Hashtbl.hash (193, tp, htp, vps)
    | VHistorically (tp, vp) -> Hashtbl.hash (197, tp, vp)
    | VAlways (tp, vp) -> Hashtbl.hash (199, tp, vp)
    | VSinceOut tp -> Hashtbl.hash (211, tp)
    | VSince (tp, vp1, vp2s) -> Hashtbl.hash (223, tp, vp1, vp2s)
    | VSinceInf (tp, ltp, vp2s) -> Hashtbl.hash (227, tp, ltp, vp2s)
    | VUntil (tp, vp1, vp2s) -> Hashtbl.hash (229, tp, vp1, vp2s)
    | VUntilInf (tp, htp, vp2s) -> Hashtbl.hash (233, tp, htp, vp2s)

  let s_hashcons =
    let s_equal x y = match x, y with
      | STT tp, STT tp' -> Int.equal tp tp'
      | SEqConst (tp, x, c), SEqConst (tp', x', c') -> Int.equal tp tp' && String.equal x x' && Domain.equal c c'
      | SPred (tp, r, terms), SPred (tp', r', terms') -> Int.equal tp tp' && String.equal r r' &&
                                                           Int.equal (List.length terms) (List.length terms') &&
                                                             List.for_all2_exn terms terms' ~f:(fun t1 t2 -> Term.equal t1 t2)
      | SNeg vp, SNeg vp'
        | SImpL vp, SImpL vp' -> phys_equal vp vp'
      | SImpR sp, SImpR sp'
        | SOrL sp, SOrL sp'
        | SOrR sp, SOrR sp'
        | SPrev sp, SPrev sp'
        | SNext sp, SNext sp' -> phys_equal sp sp'
      | SAnd (sp1, sp2), SAnd (sp1', sp2')
        | SIffSS (sp1, sp2), SIffSS (sp1', sp2') -> phys_equal sp1 sp1' && phys_equal sp2 sp2'
      | SIffVV (vp1, vp2), SIffVV (vp1', vp2') -> phys_equal vp1 vp1' && phys_equal vp2 vp2'
      | SExists (x, d, sp), SExists (x', d', sp') -> String.equal x x' && Domain.equal d d' && phys_equal sp sp'
      | SForall (x, part), SForall (x', part') -> String.equal x x' && List.for_all2_exn part part' ~f:(fun (s, p) (s', p') ->
                                                                           Setc.equal s s' && phys_equal p p')
      | SOnce (tp, sp), SOnce (tp', sp')
        | SEventually (tp, sp), SEventually (tp', sp') -> Int.equal tp tp' && phys_equal sp sp'
      | SHistoricallyOut tp, SHistoricallyOut tp' -> Int.equal tp tp'
      | SHistorically (tp, ltp, sps), SHistorically (tp', li', sps') -> Int.equal tp tp' && Int.equal ltp li' &&
                                                                         Int.equal (Fdeque.length sps) (Fdeque.length sps') &&
                                                                           Etc.fdeque_for_all2_exn sps sps' ~f:(fun sp sp' -> phys_equal sp sp')
      | SAlways (tp, htp, sps), SAlways (tp', hi', sps') -> Int.equal tp tp' && Int.equal htp hi' &&
                                                             Int.equal (Fdeque.length sps) (Fdeque.length sps') &&
                                                               Etc.fdeque_for_all2_exn sps sps' ~f:(fun sp sp' -> phys_equal sp sp')
      | SSince (sp2, sp1s), SSince (sp2', sp1s')
        | SUntil (sp2, sp1s), SUntil (sp2', sp1s') -> phys_equal sp2 sp2' && Int.equal (Fdeque.length sp1s) (Fdeque.length sp1s') &&
                                                        Etc.fdeque_for_all2_exn sp1s sp1s' ~f:(fun sp1 sp1' -> phys_equal sp1 sp1')
      | _ -> false in
    Hashcons.hashcons s_hash s_equal m1

  let v_hashcons =
    let v_equal x y = match x, y with
      | VFF tp, VFF tp' -> Int.equal tp tp'
      | VEqConst (tp, x, c), VEqConst (tp', x', c') -> Int.equal tp tp' && String.equal x x' && Domain.equal c c'
      | VPred (tp, r, terms), VPred (tp', r', terms') -> Int.equal tp tp' && String.equal r r' &&
                                                           Int.equal (List.length terms) (List.length terms') &&
                                                             List.for_all2_exn terms terms' ~f:(fun t1 t2 -> Term.equal t1 t2)
      | VNeg sp, VNeg sp' -> phys_equal sp sp'
      | VAndL vp, VAndL vp'
        | VAndR vp, VAndR vp'
        | VPrev vp, VPrev vp'
        | VNext vp, VNext vp' -> phys_equal vp vp'
      | VOr (vp1, vp2), VOr (vp1', vp2') -> phys_equal vp1 vp1' && phys_equal vp2 vp2'
      | VImp (sp1, vp2), VImp (sp1', vp2')
        | VIffSV (sp1, vp2), VIffSV (sp1', vp2') -> phys_equal sp1 sp1' && phys_equal vp2 vp2'
      | VIffVS (vp1, sp2), VIffVS (vp1', sp2') -> phys_equal vp1 vp1' && phys_equal sp2 sp2'
      | VExists (x, part), VExists (x', part') -> String.equal x x' && List.for_all2_exn part part' ~f:(fun (s, p) (s', p') ->
                                                                           Setc.equal s s' && phys_equal p p')
      | VForall (x, d, vp), VForall (x', d', vp') -> String.equal x x' && Domain.equal d d' && phys_equal vp vp'
      | VPrev0, VPrev0 -> true
      | VPrevOutL tp, VPrevOutL tp'
        | VPrevOutR tp, VPrevOutR tp'
        | VNextOutL tp, VNextOutL tp'
        | VNextOutR tp, VNextOutR tp'
        | VOnceOut tp, VOnceOut tp'
        | VSinceOut tp, VSinceOut tp' -> Int.equal tp tp'
      | VOnce (tp, ltp, vps), VOnce (tp', li', vps') -> Int.equal tp tp' && Int.equal ltp li' &&
                                                         Int.equal (Fdeque.length vps) (Fdeque.length vps') &&
                                                           Etc.fdeque_for_all2_exn vps vps' ~f:(fun vp vp' -> phys_equal vp vp')
      | VEventually (tp, htp, vps), VEventually (tp', hi', vps') -> Int.equal tp tp' && Int.equal htp hi' &&
                                                                     Int.equal (Fdeque.length vps) (Fdeque.length vps') &&
                                                                       Etc.fdeque_for_all2_exn vps vps' ~f:(fun vp vp' -> phys_equal vp vp')
      | VHistorically (tp, vp), VHistorically (tp', vp')
        | VAlways (tp, vp), VAlways (tp', vp') -> Int.equal tp tp'
      | VSince (tp, vp1, vp2s), VSince (tp', vp1', vp2s')
        | VUntil (tp, vp1, vp2s), VUntil (tp', vp1', vp2s') -> Int.equal tp tp' && phys_equal vp1 vp1' &&
                                                                 Int.equal (Fdeque.length vp2s) (Fdeque.length vp2s') &&
                                                                   Etc.fdeque_for_all2_exn vp2s vp2s' ~f:(fun vp2 vp2' -> phys_equal vp2 vp2')
      | VSinceInf (tp, ltp, vp2s), VSinceInf (tp', li', vp2s') -> Int.equal tp tp' && Int.equal ltp li' &&
                                                                   Int.equal (Fdeque.length vp2s) (Fdeque.length vp2s') &&
                                                                     Etc.fdeque_for_all2_exn vp2s vp2s' ~f:(fun vp2 vp2' -> phys_equal vp2 vp2')

      | VUntilInf (tp, htp, vp2s), VUntilInf (tp', hi', vp2s') -> Int.equal tp tp' && Int.equal htp hi' &&
                                                                   Int.equal (Fdeque.length vp2s) (Fdeque.length vp2s') &&
                                                                     Etc.fdeque_for_all2_exn vp2s vp2s' ~f:(fun vp2 vp2' -> phys_equal vp2 vp2')
      | _ -> false in
    Hashcons.hashcons v_hash v_equal m2

  let stt tp = s_hashcons (STT tp)
  let seqconst (tp, x, d) = s_hashcons (SEqConst (tp, x, d))
  let spred (tp, r, terms) = s_hashcons (SPred (tp, r, terms))
  let sneg vp = s_hashcons (SNeg vp)
  let sorl sp = s_hashcons (SOrL sp)
  let sorr sp = s_hashcons (SOrR sp)
  let sand (sp1, sp2) = s_hashcons (SAnd (sp1, sp2))
  let simpl vp = s_hashcons (SImpL vp)
  let simpr sp = s_hashcons (SImpR sp)
  let siffss (sp1, sp2) = s_hashcons (SIffSS (sp1, sp2))
  let siffvv (vp1, vp2) = s_hashcons (SIffVV (vp1, vp2))
  let sexists (x, d, sp) = s_hashcons (SExists (x, d, sp))
  let sforall (x, part) = s_hashcons (SForall (x, part))
  let sprev sp = s_hashcons (SPrev sp)
  let snext sp = s_hashcons (SNext sp)
  let sonce (tp, sp) = s_hashcons (SOnce (tp, sp))
  let seventually (tp, sp) = s_hashcons (SEventually (tp, sp))
  let shistorically (tp, ltp, sps) = s_hashcons (SHistorically (tp, ltp, sps))
  let shistoricallyout tp = s_hashcons (SHistoricallyOut tp)
  let salways (tp, htp, sps) = s_hashcons (SAlways (tp, htp, sps))
  let ssince (sp1, sp2s) = s_hashcons (SSince (sp1, sp2s))
  let suntil (sp1, sp2s) = s_hashcons (SUntil (sp1, sp2s))

  let suntil (p1, p2s) = s_hashcons (SUntil (p1, p2s))

  let vff tp = v_hashcons (VFF tp)
  let veqconst (tp, x, d) = v_hashcons (VEqConst (tp, x, d))
  let vpred (tp, r, terms) = v_hashcons (VPred (tp, r, terms))
  let vneg sp = v_hashcons (VNeg sp)
  let vor (vp1, vp2) = v_hashcons (VOr (vp1, vp2))
  let vandl vp1 = v_hashcons (VAndL vp1)
  let vandr vp2 = v_hashcons (VAndR vp2)
  let vimp (sp1, vp2) = v_hashcons (VImp (sp1, vp2))
  let viffsv (sp1, vp2) = v_hashcons (VIffSV (sp1, vp2))
  let viffvs (vp1, sp2) = v_hashcons (VIffVS (vp1, sp2))
  let vexists (x, part) = v_hashcons (VExists (x, part))
  let vforall (x, d, vp) = v_hashcons (VForall (x, d, vp))
  let vprev vp = v_hashcons (VPrev vp)
  let vprev0 = v_hashcons VPrev0
  let vprevoutl tp = v_hashcons (VPrevOutL tp)
  let vprevoutr tp = v_hashcons (VPrevOutR tp)
  let vnext vp = v_hashcons (VNext vp)
  let vnextoutl tp = v_hashcons (VNextOutL tp)
  let vnextoutr tp = v_hashcons (VNextOutR tp)
  let vonceout tp = v_hashcons (VOnceOut tp)
  let vonce (tp, ltp, vps) = v_hashcons (VOnce (tp, ltp, vps))
  let veventually (tp, htp, vps) = v_hashcons (VEventually (tp, htp, vps))
  let vhistorically (tp, vp) = v_hashcons (VHistorically (tp, vp))
  let valways (tp, vp) = v_hashcons (VAlways (tp, vp))
  let vsinceout tp = v_hashcons (VSinceOut tp)
  let vsince (tp, vp1, vp2s) = v_hashcons (VSince (tp, vp1, vp2s))
  let vsinceinf (tp, ltp, vp2s) = v_hashcons (VSinceInf (tp, ltp, vp2s))
  let vuntil (tp, vp1, vp2s) = v_hashcons (VUntil (tp, vp1, vp2s))
  let vuntilinf (tp, htp, vp2s) = v_hashcons (VUntilInf (tp, htp, vp2s))

  let memo_rec f =
    let t1 = ref Hmap.empty in
    let t2 = ref Hmap.empty in
    let rec s_aux sp =
      try Hmap.find sp !t1
      with Not_found ->
        let z = f s_aux v_aux (S sp) in
        t1 := Hmap.add sp z !t1; z
    and v_aux vp =
      try Hmap.find vp !t2
      with Not_found ->
        let z = f s_aux v_aux (V vp) in
        t2 := Hmap.add vp z !t2; z
    in (s_aux, v_aux)

  let unS = function
    | S sp -> sp
    | _ -> raise (Invalid_argument "unS is not defined for V proofs")

  let unV = function
    | V vp -> vp
    | _ -> raise (Invalid_argument "unV is not defined for S proofs")

  let isS = function
    | S _ -> true
    | V _ -> false

  let isV = function
    | S _ -> false
    | V _ -> true

  let s_append sp sp1 = match sp.Hashcons.node with
    | SSince (sp2, sp1s) -> ssince (sp2, Fdeque.enqueue_back sp1s sp1)
    | SUntil (sp2, sp1s) -> suntil (sp2, Fdeque.enqueue_back sp1s sp1)
    | _ -> raise (Invalid_argument "sappend is not defined for this sp")

  let v_append vp vp2 = match vp.Hashcons.node with
    | VSince (tp, vp1, vp2s) -> vsince (tp,  vp1, Fdeque.enqueue_back vp2s vp2)
    | VSinceInf (tp, etp, vp2s) -> vsinceinf (tp, etp, Fdeque.enqueue_back vp2s vp2)
    | VUntil (tp, vp1, vp2s) -> vuntil (tp, vp1, Fdeque.enqueue_back vp2s vp2)
    | VUntilInf (tp, ltp, vp2s) -> vuntilinf (tp, ltp, Fdeque.enqueue_back vp2s vp2)
    | _ -> raise (Invalid_argument "vappend is not defined for this vp")

  let s_drop = function
    | SUntil (sp2, sp1s) -> (match Fdeque.drop_front sp1s with
                             | None -> None
                             | Some(sp1s') -> Some (suntil (sp2, sp1s')))
    | _ -> raise (Invalid_argument "sdrop is not defined for this sp")

  let v_drop = function
    | VUntil (tp, vp1, vp2s) -> (match Fdeque.drop_front vp2s with
                                 | None -> None
                                 | Some(vp2s') -> Some (vuntil (tp, vp1, vp2s')))
    | VUntilInf (tp, ltp, vp2s) -> (match Fdeque.drop_front vp2s with
                                    | None -> None
                                    | Some(vp2s') -> Some (vuntilinf (tp, ltp, vp2s)))
    | _ -> raise (Invalid_argument "vdrop is not defined for this vp")

  let (s_at, v_at) =
    memo_rec (fun s_at v_at p ->
        match p with
        | S sp -> (match sp.node with
                   | STT tp -> tp
                   | SEqConst (tp, _, _) -> tp
                   | SPred (tp, _, _) -> tp
                   | SNeg vp -> v_at vp
                   | SOrL sp1 -> s_at sp1
                   | SOrR sp2 -> s_at sp2
                   | SAnd (sp1, _) -> s_at sp1
                   | SImpL vp1 -> v_at vp1
                   | SImpR sp2 -> s_at sp2
                   | SIffSS (sp1, _) -> s_at sp1
                   | SIffVV (vp1, _) -> v_at vp1
                   | SExists (_, _, sp) -> s_at sp
                   | SForall (_, part) -> s_at (Part.hd part)
                   | SPrev sp -> s_at sp + 1
                   | SNext sp -> s_at sp - 1
                   | SOnce (tp, _) -> tp
                   | SEventually (tp, _) -> tp
                   | SHistorically (tp, _, _) -> tp
                   | SHistoricallyOut tp -> tp
                   | SAlways (tp, _, _) -> tp
                   | SSince (sp2, sp1s) -> if Fdeque.is_empty sp1s then s_at sp2
                                           else s_at (Fdeque.peek_back_exn sp1s)
                   | SUntil (sp2, sp1s) -> if Fdeque.is_empty sp1s then s_at sp2
                                           else s_at (Fdeque.peek_front_exn sp1s))
        | V vp -> (match vp.node with
                   | VFF tp -> tp
                   | VEqConst (tp, _, _) -> tp
                   | VPred (tp, _, _) -> tp
                   | VNeg sp -> s_at sp
                   | VOr (vp1, _) -> v_at vp1
                   | VAndL vp1 -> v_at vp1
                   | VAndR vp2 -> v_at vp2
                   | VImp (sp1, _) -> s_at sp1
                   | VIffSV (sp1, _) -> s_at sp1
                   | VIffVS (vp1, _) -> v_at vp1
                   | VExists (_, part) -> v_at (Part.hd part)
                   | VForall (_, _, vp) -> v_at vp
                   | VPrev vp -> v_at vp + 1
                   | VPrev0 -> 0
                   | VPrevOutL tp -> tp
                   | VPrevOutR tp -> tp
                   | VNext vp -> v_at vp - 1
                   | VNextOutL tp -> tp
                   | VNextOutR tp -> tp
                   | VOnceOut tp -> tp
                   | VOnce (tp, _, _) -> tp
                   | VEventually (tp, _, _) -> tp
                   | VHistorically (tp, _) -> tp
                   | VAlways (tp, _) -> tp
                   | VSinceOut tp -> tp
                   | VSince (tp, _, _) -> tp
                   | VSinceInf (tp, _, _) -> tp
                   | VUntil (tp, _, _) -> tp
                   | VUntilInf (tp, _, _) -> tp))

  let p_at = function
    | S s_p -> s_at s_p
    | V v_p -> v_at v_p

  let s_ltp = function
    | SUntil (sp2, _) -> s_at sp2
    | _ -> raise (Invalid_argument "s_ltp is not defined for this sp")

  let v_etp = function
    | VUntil (tp, _, vp2s) -> if Fdeque.is_empty vp2s then tp
                              else v_at (Fdeque.peek_front_exn vp2s)
    | _ -> raise (Invalid_argument "v_etp is not defined for this vp")

  let cmp f p1 p2 = f p1 <= f p2

  let rec s_to_string indent p =
    let indent' = "\t" ^ indent in
    match p.Hashcons.node with
    | STT i -> Printf.sprintf "%strue{%d}" indent i
    | SEqConst (tp, x, c) -> Printf.sprintf "%sSEqConst(%d, %s, %s)" indent tp x (Domain.to_string c)
    | SPred (tp, r, trms) -> Printf.sprintf "%sSPred(%d, %s, %s)" indent tp r (Term.list_to_string trms)
    | SNeg vp -> Printf.sprintf "%sSNeg{%d}\n%s" indent (s_at p) (v_to_string indent' vp)
    | SOrL sp1 -> Printf.sprintf "%sSOrL{%d}\n%s" indent (s_at p) (s_to_string indent' sp1)
    | SOrR sp2 -> Printf.sprintf "%sSOrR{%d}\n%s" indent (s_at p) (s_to_string indent' sp2)
    | SAnd (sp1, sp2) -> Printf.sprintf "%sSAnd{%d}\n%s\n%s" indent (s_at p)
                           (s_to_string indent' sp1) (s_to_string indent' sp2)
    | SImpL vp1 -> Printf.sprintf "%sSImpL{%d}\n%s" indent (s_at p) (v_to_string indent' vp1)
    | SImpR sp2 -> Printf.sprintf "%sSImpR{%d}\n%s" indent (s_at p) (s_to_string indent' sp2)
    | SIffSS (sp1, sp2) -> Printf.sprintf "%sSIffSS{%d}\n%s\n%s" indent (s_at p)
                             (s_to_string indent' sp1) (s_to_string indent' sp2)
    | SIffVV (vp1, vp2) -> Printf.sprintf "%sSIffVV{%d}\n%s\n%s" indent (s_at p)
                             (v_to_string indent' vp1) (v_to_string indent' vp2)
    | SExists (x, d, sp) -> Printf.sprintf "%sSExists{%d}{%s=%s}\n%s\n" indent (s_at p)
                              x (Domain.to_string d) (s_to_string indent' sp)
    | SForall (x, part) -> Printf.sprintf "%sSForall{%d}{%s}\n%s\n" indent (s_at (sforall (x, part)))
                             x (Part.to_string indent' (Var x) s_to_string part)
    | SPrev sp -> Printf.sprintf "%sSPrev{%d}\n%s" indent (s_at p) (s_to_string indent' sp)
    | SNext sp -> Printf.sprintf "%sSNext{%d}\n%s" indent (s_at p) (s_to_string indent' sp)
    | SOnce (_, sp) -> Printf.sprintf "%sSOnce{%d}\n%s" indent (s_at p) (s_to_string indent' sp)
    | SEventually (_, sp) -> Printf.sprintf "%sSEventually{%d}\n%s" indent (s_at p)
                               (s_to_string indent' sp)
    | SHistorically (_, _, sps) -> Printf.sprintf "%sSHistorically{%d}\n%s" indent (s_at p)
                                     (Etc.deque_to_string indent' s_to_string sps)
    | SHistoricallyOut i -> Printf.sprintf "%sSHistoricallyOut{%d}" indent' i
    | SAlways (_, _, sps) -> Printf.sprintf "%sSAlways{%d}\n%s" indent (s_at p)
                               (Etc.deque_to_string indent' s_to_string sps)
    | SSince (sp2, sp1s) -> Printf.sprintf "%sSSince{%d}\n%s\n%s" indent (s_at p) (s_to_string indent' sp2)
                              (Etc.deque_to_string indent' s_to_string sp1s)
    | SUntil (sp2, sp1s) -> Printf.sprintf "%sSUntil{%d}\n%s\n%s" indent (s_at p)
                              (Etc.deque_to_string indent' s_to_string sp1s) (s_to_string indent' sp2)
  and v_to_string indent p =
    let indent' = "\t" ^ indent in
    match p.node with
    | VFF i -> Printf.sprintf "%sfalse{%d}" indent i
    | VEqConst (tp, x, c) -> Printf.sprintf "%sVEqConst(%d, %s, %s)" indent tp x (Domain.to_string c)
    | VPred (tp, r, trms) -> Printf.sprintf "%sVPred(%d, %s, %s)" indent tp r (Term.list_to_string trms)
    | VNeg sp -> Printf.sprintf "%sVNeg{%d}\n%s" indent (v_at p) (s_to_string indent' sp)
    | VOr (vp1, vp2) -> Printf.sprintf "%sVOr{%d}\n%s\n%s" indent (v_at p) (v_to_string indent' vp1) (v_to_string indent' vp2)
    | VAndL vp1 -> Printf.sprintf "%sVAndL{%d}\n%s" indent (v_at p) (v_to_string indent' vp1)
    | VAndR vp2 -> Printf.sprintf "%sVAndR{%d}\n%s" indent (v_at p) (v_to_string indent' vp2)
    | VImp (sp1, vp2) -> Printf.sprintf "%sVImp{%d}\n%s\n%s" indent (v_at p) (s_to_string indent' sp1) (v_to_string indent' vp2)
    | VIffSV (sp1, vp2) -> Printf.sprintf "%sVIffSV{%d}\n%s\n%s" indent (v_at p) (s_to_string indent' sp1) (v_to_string indent' vp2)
    | VIffVS (vp1, sp2) -> Printf.sprintf "%sVIffVS{%d}\n%s\n%s" indent (v_at p) (v_to_string indent' vp1) (s_to_string indent' sp2)
    | VExists (x, part) -> Printf.sprintf "%sVExists{%d}{%s}\n%s\n" indent (v_at (vexists (x, part)))
                             x (Part.to_string indent' (Var x) v_to_string part)
    | VForall (x, d, vp) -> Printf.sprintf "%sVForall{%d}{%s=%s}\n%s\n" indent (v_at p)
                              x (Domain.to_string d) (v_to_string indent' vp)
    | VPrev vp -> Printf.sprintf "%sVPrev{%d}\n%s" indent (v_at p) (v_to_string indent' vp)
    | VPrev0 -> Printf.sprintf "%sVPrev0{0}" indent'
    | VPrevOutL i -> Printf.sprintf "%sVPrevOutL{%d}" indent' i
    | VPrevOutR i -> Printf.sprintf "%sVPrevOutR{%d}" indent' i
    | VNext vp -> Printf.sprintf "%sVNext{%d}\n%s" indent (v_at p) (v_to_string indent' vp)
    | VNextOutL i -> Printf.sprintf "%sVNextOutL{%d}" indent' i
    | VNextOutR i -> Printf.sprintf "%sVNextOutR{%d}" indent' i
    | VOnceOut i -> Printf.sprintf "%sVOnceOut{%d}" indent' i
    | VOnce (_, _, vps) -> Printf.sprintf "%sVOnce{%d}\n%s" indent (v_at p)
                             (Etc.deque_to_string indent' v_to_string vps)
    | VEventually (_, _, vps) -> Printf.sprintf "%sVEventually{%d}\n%s" indent (v_at p)
                                   (Etc.deque_to_string indent' v_to_string vps)
    | VHistorically (_, vp) -> Printf.sprintf "%sVHistorically{%d}\n%s" indent (v_at p) (v_to_string indent' vp)
    | VAlways (_, vp) -> Printf.sprintf "%sVAlways{%d}\n%s" indent (v_at p) (v_to_string indent' vp)
    | VSinceOut i -> Printf.sprintf "%sVSinceOut{%d}" indent' i
    | VSince (_, vp1, vp2s) -> Printf.sprintf "%sVSince{%d}\n%s\n%s" indent (v_at p) (v_to_string indent' vp1)
                                 (Etc.deque_to_string indent' v_to_string vp2s)
    | VSinceInf (_, _, vp2s) -> Printf.sprintf "%sVSinceInf{%d}\n%s" indent (v_at p)
                                  (Etc.deque_to_string indent' v_to_string vp2s)
    | VUntil (_, vp1, vp2s) -> Printf.sprintf "%sVUntil{%d}\n%s\n%s" indent (v_at p)
                                 (Etc.deque_to_string indent' v_to_string vp2s) (v_to_string indent' vp1)
    | VUntilInf (_, _, vp2s) -> Printf.sprintf "%sVUntilInf{%d}\n%s" indent (v_at p)
                                  (Etc.deque_to_string indent' v_to_string vp2s)

  let to_string indent = function
    | S p -> s_to_string indent p
    | V p -> v_to_string indent p

  let val_changes_to_latex v =
    if List.is_empty v then "v"
    else "v[" ^ Etc.string_list_to_string (List.map v ~f:(fun (x, d) -> Printf.sprintf "%s \\mapsto %s" x d)) ^ "]"

  let rec s_to_latex indent v idx p (h: Formula.t) =
    let indent' = "\t" ^ indent in
    match p.Hashcons.node, h with
    | STT tp, TT  ->
       Printf.sprintf "\\infer[\\top]{%s, %d \\pvd true}{}\n" (val_changes_to_latex v) tp
    | SEqConst (tp, x, c), EqConst (_, _) ->
       Printf.sprintf "\\infer[\\Seqconst]{%s, %d \\pvd %s \\approx %s}{%s \\approx %s}\n"
         (val_changes_to_latex v) tp (Etc.escape_underscores x) (Domain.to_string c)
         (Etc.escape_underscores x) (Domain.to_string c)
    | SPred (tp, r, trms), Predicate (_, _) ->
       Printf.sprintf "\\infer[\\Spred]{%s, %d \\pvd %s\\,(%s)}{(%s,[%s]) \\in\\Gamma_{%d}}\n"
         (val_changes_to_latex v) tp (Etc.escape_underscores r) (Term.list_to_string trms)
         (Etc.escape_underscores r) (Term.list_to_string trms) tp
    | SNeg vp, Neg f ->
       Printf.sprintf "\\infer[\\Sneg]{%s, %d \\pvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent (v_to_latex indent' v idx vp f)
    | SOrL sp1, Or (f, g) ->
       Printf.sprintf "\\infer[\\Sdisjl]{%s, %d \\pvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent (s_to_latex indent' v idx sp1 f)
    | SOrR sp2, Or (f, g) ->
       Printf.sprintf "\\infer[\\Sdisjr]{%s, %d \\pvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent (s_to_latex indent' v idx sp2 g)
    | SAnd (sp1, sp2), And (f, g) ->
       Printf.sprintf "\\infer[\\Sconj]{%s, %d \\pvd %s}\n%s{{%s} & {%s}}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h)
         indent (s_to_latex indent' v idx sp1 f) (s_to_latex indent' v idx sp2 g)
    | SImpL vp1, Imp (f, g) ->
       Printf.sprintf "\\infer[\\SimpL]{%s, %d \\pvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent (v_to_latex indent' v idx vp1 f)
    | SImpR sp2, Imp (f, g) ->
       Printf.sprintf "\\infer[\\SimpR]{%s, %d \\pvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent (s_to_latex indent' v idx sp2 g)
    | SIffSS (sp1, sp2), Iff (f, g) ->
       Printf.sprintf "\\infer[\\SiffSS]{%s, %d \\pvd %s}\n%s{{%s} & {%s}}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h)
         indent (s_to_latex indent' v idx sp1 f) (s_to_latex indent' v idx sp2 g)
    | SIffVV (vp1, vp2), Iff (f, g) ->
       Printf.sprintf "\\infer[\\SiffVV]{%s, %d \\pvd %s}\n%s{{%s} & {%s}}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h)
         indent (v_to_latex indent' v idx vp1 f) (v_to_latex indent' v idx vp2 g)
    | SExists (x, d, sp), Exists (_, f) ->
       let v' = v @ [(x, Domain.to_string d)] in
       Printf.sprintf "\\infer[\\Sexists]{%s, %d \\pvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent (s_to_latex indent' v' idx sp f)
    | SForall (x, part), Forall (_, f) ->
       Printf.sprintf "\\infer[\\Sforall]{%s, %d \\pvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent
         (String.concat ~sep:"&" (List.map part ~f:(fun (sub, sp) ->
                                      let idx' = idx + 1 in
                                      let v' = v @ [(x, "d_" ^ (Int.to_string idx') ^ " \\in " ^ (Setc.to_latex sub))] in
                                      "{" ^ (s_to_latex indent' v' idx' sp f) ^ "}")))
    | SPrev sp, Prev (i, f) ->
       Printf.sprintf "\\infer[\\Sprev{}]{%s, %d \\pvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent (s_to_latex indent' v idx sp f)
    | SNext sp, Next (i, f) ->
       Printf.sprintf "\\infer[\\Snext{}]{%s, %d \\pvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent (s_to_latex indent' v idx sp f)
    | SOnce (tp, sp), Once (i, f) ->
       Printf.sprintf "\\infer[\\Sonce{}]{%s, %d \\pvd %s}\n%s{{%d \\leq %d} & {\\tau_%d - \\tau_%d \\in %s} & {%s}}\n"
         (val_changes_to_latex v) tp (Formula.to_latex h) indent
         (s_at sp) tp tp (s_at sp) (Interval.to_latex i) (s_to_latex indent' v idx sp f)
    | SEventually (tp, sp), Eventually (i, f) ->
       Printf.sprintf "\\infer[\\Seventually{}]{%s, %d \\pvd %s}\n%s{{%d \\geq %d} & {\\tau_%d - \\tau_%d \\in %s} & {%s}}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent
         (s_at sp) tp (s_at sp) tp (Interval.to_latex i) (s_to_latex indent' v idx sp f)
    | SHistorically (tp, _, sps), Historically (i, f) ->
       Printf.sprintf "\\infer[\\Shistorically{}]{%s, %d \\pvd %s}\n%s{{\\tau_%d - \\tau_0 \\geq %d} & %s}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent tp (Interval.left i)
         (String.concat ~sep:"&" (Fdeque.to_list (Fdeque.map sps ~f:(fun sp -> "{" ^ (s_to_latex indent' v idx sp f) ^ "}"))))
    | SHistoricallyOut _, Historically (i, f) ->
       Printf.sprintf "\\infer[\\ShistoricallyL{}]{%s, %d \\pvd %s}\n%s{\\tau_%d - \\tau_0 < %d}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent (s_at p) (Interval.left i)
    | SAlways (_, _, sps), Always (i, f) ->
       Printf.sprintf "\\infer[\\Salways{}]{%s, %d \\pvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent
         (String.concat ~sep:"&" (Fdeque.to_list (Fdeque.map sps ~f:(fun sp -> "{" ^ (s_to_latex indent' v idx sp f) ^ "}"))))
    | SSince (sp2, sp1s), Since (i, f, g) ->
       Printf.sprintf "\\infer[\\Ssince{}]{%s, %d \\pvd %s}\n%s{{%d \\leq %d} & {\\tau_%d - \\tau_%d \\in %s} & {%s} & %s}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent
         (s_at sp2) (s_at p) (s_at p) (s_at sp2) (Interval.to_latex i) (s_to_latex indent' v idx sp2 g)
         (String.concat ~sep:"&" (Fdeque.to_list (Fdeque.map sp1s ~f:(fun sp -> "{" ^ (s_to_latex indent' v idx sp f) ^ "}"))))
    | SUntil (sp2, sp1s), Until (i, f, g) ->
       Printf.sprintf "\\infer[\\Suntil{}]{%s, %d \\pvd %s}\n%s{{%d \\leq %d} & {\\tau_%d - \\tau_%d \\in %s} & %s & {%s}}\n"
         (val_changes_to_latex v) (s_at p) (Formula.to_latex h) indent
         (s_at p) (s_at sp2) (s_at sp2) (s_at p) (Interval.to_latex i)
         (String.concat ~sep:"&" (Fdeque.to_list (Fdeque.map sp1s ~f:(fun sp -> "{" ^ (s_to_latex indent' v idx sp f) ^ "}"))))
         (s_to_latex indent' v idx sp2 g)
    | _ -> ""
  and v_to_latex indent v idx p (h: Formula.t) =
    let indent' = "\t" ^ indent in
    match p.node, h with
    | VFF tp, FF ->
       Printf.sprintf "\\infer[\\bot]{%s, %d \\nvd false}{}\n" (val_changes_to_latex v) tp
    | VEqConst (tp, x, c), EqConst (_, _) ->
       Printf.sprintf "\\infer[\\Veqconst]{%s, %d \\nvd %s \\approx %s}{%s \\not\\approx %s}\n"
         (val_changes_to_latex v) tp (Etc.escape_underscores x) (Domain.to_string c)
         (Etc.escape_underscores x) (Domain.to_string c)
    | VPred (tp, r, trms), Predicate (_, _) ->
       Printf.sprintf "\\infer[\\Vpred]{%s, %d \\nvd %s\\,(%s)}{(%s,[%s]) \\notin\\Gamma_{%d}}\n"
         (val_changes_to_latex v) tp (Etc.escape_underscores r) (Term.list_to_string trms)
         (Etc.escape_underscores r) (Term.list_to_string trms) tp
    | VNeg sp, Neg f ->
       Printf.sprintf "\\infer[\\Vneg]{%s, %d \\nvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent (s_to_latex indent' v idx sp f)
    | VOr (vp1, vp2), Or (f, g) ->
       Printf.sprintf "\\infer[\\Vdisj]{%s, %d \\nvd %s}\n%s{{%s} & {%s}}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h)
         indent (v_to_latex indent' v idx vp1 f) (v_to_latex indent' v idx vp2 g)
    | VAndL vp1, And (f, _) ->
       Printf.sprintf "\\infer[\\Vconjl]{%s, %d \\nvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent (v_to_latex indent' v idx vp1 f)
    | VAndR vp2, And (_, g) ->
       Printf.sprintf "\\infer[\\Vconjr]{%s, %d \\nvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent (v_to_latex indent' v idx vp2 g)
    | VImp (sp1, vp2), Imp (f, g) ->
       Printf.sprintf "\\infer[\\Vimp]{%s, %d \\nvd %s}\n%s{{%s} & {%s}}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h)
         indent (s_to_latex indent' v idx sp1 f) (v_to_latex indent' v idx vp2 g)
    | VIffSV (sp1, vp2), Iff (f, g) ->
       Printf.sprintf "\\infer[\\ViffSV]{%s, %d \\nvd %s}\n%s{{%s} & {%s}}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h)
         indent (s_to_latex indent' v idx sp1 f) (v_to_latex indent' v idx vp2 g)
    | VIffVS (vp1, sp2), Iff (f, g) ->
       Printf.sprintf "\\infer[\\ViffSV]{%s, %d \\nvd %s}\n%s{{%s} & {%s}}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h)
         indent (v_to_latex indent' v idx vp1 f) (s_to_latex indent' v idx sp2 g)
    | VExists (x, part), Exists (_, f) ->
       Printf.sprintf "\\infer[\\Vexists]{%s, %d \\nvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent
         (String.concat ~sep:"&" (List.map part ~f:(fun (sub, vp) ->
                                      let idx' = idx + 1 in
                                      let v' = v @ [(x, "d_" ^ (Int.to_string idx') ^ " \\in " ^ (Setc.to_latex sub))] in
                                      "{" ^ (v_to_latex indent' v' idx' vp f) ^ "}")))
    | VForall (x, d, vp), Forall (_, f) ->
       let v' = v @ [(x, Domain.to_string d)] in
       Printf.sprintf "\\infer[\\Vforall]{%s, %d \\nvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent (v_to_latex indent' v' idx vp f)
    | VPrev vp, Prev (i, f) ->
       Printf.sprintf "\\infer[\\Vprev{}]{%s, %d \\nvd %s}\n%s{{%d > 0} & {%s}}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent (v_at p) (v_to_latex indent' v idx vp f)
    | VPrev0, Prev (i, f) ->
       Printf.sprintf "\\infer[\\Vprevz]{%s, %d \\nvd %s}{}\n" (val_changes_to_latex v) (v_at p) (Formula.to_latex h)
    | VPrevOutL tp, Prev (i, f) ->
       Printf.sprintf "\\infer[\\Vprevl]{%s, %d \\nvd %s}\n%s{{%d > 0} & {\\tau_%d - \\tau_%d < %d}}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent (v_at p) (v_at p) ((v_at p)-1) (Interval.left i)
    | VPrevOutR tp, Prev (i, f) ->
       Printf.sprintf "\\infer[\\Vprevr]{%s, %d \\nvd %s}\n%s{{%d > 0} & {\\tau_%d - \\tau_%d > %d}}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent (v_at p) (v_at p) ((v_at p)-1) (Option.value_exn (Interval.right i))
    | VNext vp, Next (i, f) ->
       Printf.sprintf "\\infer[\\Vnext{}]{%s, %d \\nvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent (v_to_latex indent' v idx vp f)
    | VNextOutL tp, Next (i, f) ->
       Printf.sprintf "\\infer[\\Vnextl]{%s, %d \\nvd %s}{\\tau_%d - \\tau_%d < %d}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) ((v_at p)+1) (v_at p) (Interval.left i)
    | VNextOutR tp, Next (i, f) ->
       Printf.sprintf "\\infer[\\Vnextr]{%s, %d \\nvd %s}{\\tau_%d - \\tau_%d > %d}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) ((v_at p)+1) (v_at p) (Option.value_exn (Interval.right i))
    | VOnceOut tp, Once (i, f) ->
       Printf.sprintf "\\infer[\\Voncel{}]{%s, %d \\nvd %s}\n%s{\\tau_%d - \\tau_0 < %d}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent (v_at p) (Interval.left i)
    | VOnce (_, _, vps), Once (i, f) ->
       Printf.sprintf "\\infer[\\Vonce{}]{%s, %d \\nvd %s}\n%s{{\\tau_%d - \\tau_0 \\geq %d} & %s}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent (v_at p) (Interval.left i)
         (String.concat ~sep:"&" (Fdeque.to_list (Fdeque.map vps ~f:(fun vp -> "{" ^ (v_to_latex indent' v idx vp f) ^ "}"))))
    | VEventually (_, _, vps), Eventually (i, f) ->
       Printf.sprintf "\\infer[\\Veventually{}]{%s, %d \\nvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent
         (String.concat ~sep:"&" (Fdeque.to_list (Fdeque.map vps ~f:(fun vp -> "{" ^ (v_to_latex indent' v idx vp f) ^ "}"))))
    | VHistorically (tp, vp), Historically (i, f) ->
       Printf.sprintf "\\infer[\\Vhistorically{}]{%s, %d \\nvd %s}\n%s{{%d \\leq %d} & {\\tau_%d - \\tau_%d \\in %s} & {%s}}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent
         (v_at vp) tp tp (v_at vp) (Interval.to_latex i) (v_to_latex indent' v idx vp f)
    | VAlways (tp, vp), Always (i, f) ->
       Printf.sprintf "\\infer[\\Valways{}]{%s, %d \\nvd %s}\n%s{{%d \\geq %d} & {\\tau_%d - \\tau_%d \\in %s} & {%s}}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent
         (v_at vp) tp (v_at vp) tp (Interval.to_latex i) (v_to_latex indent' v idx vp f)
    | VSinceOut tp, Since (i, f, g) ->
       Printf.sprintf "\\infer[\\Vsincel{}]{%s, %d \\nvd %s}\n%s{\\tau_%d - \\tau_0 < %d}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent (v_at p) (Interval.left i)
    | VSince (tp, vp1, vp2s), Since (i, f, g) ->
       Printf.sprintf "\\infer[\\Vsince{}]{%s, %d \\nvd %s}\n%s{{%d \\leq %d} & {\\tau_%d - \\tau_0 \\geq %d} & {%s} & %s}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent
         (v_at vp1) tp tp (Interval.left i) (v_to_latex indent' v idx vp1 f)
         (String.concat ~sep:"&" (Fdeque.to_list (Fdeque.map vp2s ~f:(fun vp -> "{" ^ (v_to_latex indent' v idx vp g) ^ "}"))))
    | VSinceInf (tp, _, vp2s), Since (i, f, g) ->
       Printf.sprintf "\\infer[\\Vsinceinf{}]{%s, %d \\nvd %s}\n%s{{\\tau_%d - \\tau_0 \\geq %d} & %s}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent tp (Interval.left i)
         (String.concat ~sep:"&" (Fdeque.to_list (Fdeque.map vp2s ~f:(fun vp -> "{" ^ (v_to_latex indent' v idx vp g) ^ "}"))))
    | VUntil (tp, vp1, vp2s), Until (i, f, g) ->
       Printf.sprintf "\\infer[\\Vuntil{}]{%s, %d \\nvd %s}\n%s{{%d \\leq %d} & %s & {%s}}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent tp (v_at vp1)
         (String.concat ~sep:"&" (Fdeque.to_list (Fdeque.map vp2s ~f:(fun vp -> "{" ^ (v_to_latex indent' v idx vp g) ^ "}"))))
         (v_to_latex indent' v idx vp1 f)
    | VUntilInf (_, _, vp2s), Until (i, f, g) ->
       Printf.sprintf "\\infer[\\Vuntil{}]{%s, %d \\nvd %s}\n%s{%s}\n"
         (val_changes_to_latex v) (v_at p) (Formula.to_latex h) indent
         (String.concat ~sep:"&" (Fdeque.to_list (Fdeque.map vp2s ~f:(fun vp -> "{" ^ (v_to_latex indent' v idx vp g) ^ "}"))))
    | _ -> ""

  let to_latex indent fmla = function
    | S p -> s_to_latex indent [] 0 p fmla
    | V p -> v_to_latex indent [] 0 p fmla

  module Size = struct

    let sum f d = Fdeque.fold d ~init:0 ~f:(fun acc p -> acc + f p)

    let (s, v) =
      memo_rec (fun s v p ->
          match p with
          | S sp -> (match sp.node with
                     | STT _ -> 1
                     | SEqConst _ -> 1
                     | SPred _ -> 1
                     | SNeg vp -> 1 + v vp
                     | SOrL sp1 -> 1 + s sp1
                     | SOrR sp2 -> 1 + s sp2
                     | SAnd (sp1, sp2) -> 1 + s sp1 + s sp2
                     | SImpL vp1 -> 1 + v vp1
                     | SImpR sp2 -> 1 + s sp2
                     | SIffSS (sp1, sp2) -> 1 + s sp1 + s sp2
                     | SIffVV (vp1, vp2) -> 1 + v vp1 + v vp2
                     | SExists (_, _, sp) -> 1 + s sp
                     | SForall (_, part) -> 1 + (Part.fold_left part 0 (fun a sp -> a + s sp))
                     | SPrev sp -> 1 + s sp
                     | SNext sp -> 1 + s sp
                     | SOnce (_, sp) -> 1 + s sp
                     | SEventually (_, sp) -> 1 + s sp
                     | SHistorically (_, _, sps) -> 1 + sum s sps
                     | SHistoricallyOut _ -> 1
                     | SAlways (_, _, sps) -> 1 + sum s sps
                     | SSince (sp2, sp1s) -> 1 + s sp2 + sum s sp1s
                     | SUntil (sp2, sp1s) -> 1 + s sp2 + sum s sp1s)
          | V vp -> (match vp.node with
                     | VFF _ -> 1
                     | VEqConst _ -> 1
                     | VPred _ -> 1
                     | VNeg sp -> 1 + s sp
                     | VOr (vp1, vp2) -> 1 + v vp1 + v vp2
                     | VAndL vp1 -> 1 + v vp1
                     | VAndR vp2 -> 1 + v vp2
                     | VImp (sp1, vp2) -> 1 + s sp1 + v vp2
                     | VIffSV (sp1, vp2) -> 1 + s sp1 + v vp2
                     | VIffVS (vp1, sp2) -> 1 + v vp1 + s sp2
                     | VExists (_, part) -> 1 + (Part.fold_left part 0 (fun a vp -> a + v vp))
                     | VForall (_, _, vp) -> 1 + v vp
                     | VPrev vp -> 1 + v vp
                     | VPrev0 -> 1
                     | VPrevOutL _ -> 1
                     | VPrevOutR _ -> 1
                     | VNext vp -> 1 + v vp
                     | VNextOutL _ -> 1
                     | VNextOutR _ -> 1
                     | VOnceOut _ -> 1
                     | VOnce (_, _, vp1s) -> 1 + sum v vp1s
                     | VEventually (_, _, vp1s) -> 1 + sum v vp1s
                     | VHistorically (_, vp1) -> 1 + v vp1
                     | VAlways (_, vp1) -> 1 + v vp1
                     | VSinceOut _ -> 1
                     | VSince (_, vp1, vp2s) -> 1 + v vp1 + sum v vp2s
                     | VSinceInf (_, _, vp2s) -> 1 + sum v vp2s
                     | VUntil (_, vp1, vp2s) -> 1 + v vp1 + sum v vp2s
                     | VUntilInf (_, _, vp2s) -> 1 + sum v vp2s))

    let p = function
      | S s_p -> s s_p
      | V v_p -> v v_p

    let minp_bool = cmp p

    let minp x y = if p x <= p y then x else y

    let minp_list = function
      | [] -> raise (Invalid_argument "function not defined for empty lists")
      | x :: xs -> List.fold_left xs ~init:x ~f:minp

  end

end

module Pdt = struct

  type 'a t = Leaf of 'a | Node of string * ('a t) Part.t

  let rec apply1 vars f pdt = match vars, pdt with
    | _ , Leaf l -> Leaf (f l)
    | z :: vars, Node (x, part) ->
       if String.equal x z then
         Node (x, Part.map part (apply1 vars f))
       else apply1 vars f (Node (x, part))
    | _ -> raise (Invalid_argument "variable list is empty")

  let rec apply2 vars f pdt1 pdt2 = match vars, pdt1, pdt2 with
    | _ , Leaf l1, Leaf l2 -> Leaf (f l1 l2)
    | _ , Leaf l1, Node (x, part2) -> Node (x, Part.map part2 (apply1 vars (f l1)))
    | _ , Node (x, part1), Leaf l2 -> Node (x, Part.map part1 (apply1 vars (fun l1 -> f l1 l2)))
    | z :: vars, Node (x, part1), Node (y, part2) ->
       if String.equal x z && String.equal y z then
         Node (z, Part.merge2 (apply2 vars f) part1 part2)
       else (if String.equal x z then
               Node (x, Part.map part1 (fun pdt1 -> apply2 vars f pdt1 (Node (y, part2))))
             else (if String.equal y z then
                     Node (y, Part.map part2 (apply2 vars f (Node (x, part1))))
                   else apply2 vars f (Node (x, part1)) (Node (y, part2))))
    | _ -> raise (Invalid_argument "variable list is empty")

  let rec apply3 vars f pdt1 pdt2 pdt3 = match vars, pdt1, pdt2, pdt3 with
    | _ , Leaf l1, Leaf l2, Leaf l3 -> Leaf (f l1 l2 l3)
    | _ , Leaf l1, Leaf l2, Node (x, part3) ->
       Node (x, Part.map part3 (apply1 vars (fun l3 -> f l1 l2 l3)))
    | _ , Leaf l1, Node (x, part2), Leaf l3 ->
       Node (x, Part.map part2 (apply1 vars (fun l2 -> f l1 l2 l3)))
    | _ , Node (x, part1), Leaf l2, Leaf l3 ->
       Node (x, Part.map part1 (apply1 vars (fun l1 -> f l1 l2 l3)))
    | w :: vars, Leaf l1, Node (y, part2), Node (z, part3) ->
       if String.equal y w && String.equal z w then
         Node (w, Part.merge2 (apply2 vars (f l1)) part2 part3)
       else (if String.equal y w then
               Node (y, Part.map part2 (fun pdt2 -> apply2 vars (f l1) pdt2 (Node (z, part3))))
             else (if String.equal z w then
                     Node (z, Part.map part3 (fun pdt3 -> apply2 vars (f l1) (Node (y, part2)) pdt3))
                   else apply3 vars f (Leaf l1) (Node (y, part2)) (Node(z, part3))))
    | w :: vars, Node (x, part1), Node (y, part2), Leaf l3 ->
       if String.equal x w && String.equal y w then
         Node (w, Part.merge2 (apply2 vars (fun l1 l2 -> f l1 l2 l3)) part1 part2)
       else (if String.equal x w then
               Node (x, Part.map part1 (fun pdt1 -> apply2 vars (fun pt1 pt2 -> f pt1 pt2 l3) pdt1 (Node (y, part2))))
             else (if String.equal y w then
                     Node (y, Part.map part2 (fun pdt2 -> apply2 vars (fun l1 l2 -> f l1 l2 l3) (Node (x, part1)) pdt2))
                   else apply3 vars f (Node (x, part1)) (Node (y, part2)) (Leaf l3)))
    | w :: vars, Node (x, part1), Leaf l2, Node (z, part3) ->
       if String.equal x w && String.equal z w then
         Node (w, Part.merge2 (apply2 vars (fun l1 -> f l1 l2)) part1 part3)
       else (if String.equal x w then
               Node (x, Part.map part1 (fun pdt1 -> apply2 vars (fun l1 -> f l1 l2) pdt1 (Node (z, part3))))
             else (if String.equal z w then
                     Node (z, Part.map part3 (fun pdt3 -> apply2 vars (fun l1 -> f l1 l2) (Node (x, part1)) pdt3))
                   else apply3 vars f (Node (x, part1)) (Leaf l2) (Node (z, part3))))
    | w :: vars, Node (x, part1), Node (y, part2), Node (z, part3) ->
       if String.equal x w && String.equal y w && String.equal z w then
         Node (z, Part.merge3 (apply3 vars f) part1 part2 part3)
       else (if String.equal x w && String.equal y w then
               Node (w, Part.merge2 (fun pdt1 pdt2 -> apply3 vars f pdt1 pdt2 (Node (z, part3))) part1 part2)
             else (if String.equal x w && String.equal z w then
                     Node (w, Part.merge2 (fun pdt1 pdt3 -> apply3 vars f pdt1 (Node (y, part2)) pdt3) part1 part3)
                   else (if String.equal y w && String.equal z w then
                           Node (w, Part.merge2 (apply3 vars (fun l1 -> f l1) (Node (x, part1))) part2 part3)
                         else (if String.equal x w then
                                 Node (x, Part.map part1 (fun pdt1 -> apply3 vars f pdt1 (Node (y, part2)) (Node (z, part3))))
                               else (if String.equal y w then
                                       Node (y, Part.map part2 (fun pdt2 -> apply3 vars f (Node (x, part1)) pdt2 (Node (z, part3))))
                                     else (if String.equal z w then
                                             Node (z, Part.map part3 (fun pdt3 -> apply3 vars f (Node (x, part1)) (Node (y, part2)) pdt3))
                                           else apply3 vars f (Node (x, part1)) (Node (y, part2)) (Node (z, part3))))))))
    | _ -> raise (Invalid_argument "variable list is empty")

  let rec split_prod = function
    | Leaf (l1, l2) -> (Leaf l1, Leaf l2)
    | Node (x, part) -> let (part1, part2) = Part.split_prod (Part.map part split_prod) in
                        (Node (x, part1), Node (x, part2))

  let rec split_list = function
    | Leaf l -> List.map l ~f:(fun el -> Leaf el)
    | Node (x, part) -> List.map (Part.split_list (Part.map part split_list)) ~f:(fun el -> Node (x, el))

  let rec to_string f indent = function
    | Leaf pt -> Printf.sprintf "%s%s\n" indent (f pt)
    | Node (x, part) -> (Part.to_string indent (Var x) (to_string f) part)

  let rec to_latex f indent = function
    | Leaf pt -> Printf.sprintf "%s%s\n" indent (f pt)
    | Node (x, part) -> (Part.to_string indent (Var x) (to_latex f) part)

  let unleaf = function
    | Leaf l -> l
    | _ -> raise (Invalid_argument "function not defined for nodes")

  let rec hide vars f pdt =
    match vars, pdt with
    |  _ , Leaf l -> Leaf (f (Either.First l))
    | [x], Node (y, part) -> Leaf (f (Either.Second (Part.map part unleaf)))
    | x :: vars, Node (y, part) -> if String.equal x y then
                                     Node (y, Part.map part (hide vars f))
                                   else hide vars f (Node (y, part))
    | _ -> raise (Invalid_argument "function not defined for other cases")

end

type t = Proof.t Pdt.t

let rec at = function
  | Pdt.Leaf pt -> Proof.p_at pt
  | Node (_, part) -> at (Part.hd part)

let to_string expl = Pdt.to_string (Proof.to_string "") "" expl

let to_latex fmla expl = Pdt.to_latex (Proof.to_latex "" fmla) "" expl
