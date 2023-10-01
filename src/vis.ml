(*******************************************************************)
(*     This is part of WhyMon, and it is distributed under the     *)
(*     terms of the GNU Lesser General Public License version 3    *)
(*           (see file LICENSE for more details)                   *)
(*                                                                 *)
(*  Copyright 2023:                                                *)
(*  Leonardo Lima (UCPH)                                           *)
(*******************************************************************)

open Base
open Etc

module Fdeque = Core.Fdeque

type period = PAST | FUTURE

module Dbs = struct

  type cell = timepoint * int * Db.t

  type row = cell list

  let row tp db f : row =
    List.rev (List.foldi (Set.to_list (Formula.pred_names f)) ~init:[] ~f:(fun idx acc r ->
                  (tp, idx, Set.filter db ~f:(fun (r', _) -> String.equal r r')) :: acc))

  let cell_to_json indent tp idx db =
    (Printf.sprintf "%s{\n" indent) ^
      (Printf.sprintf "%s\"tp\": %d,\n" (indent ^ (String.make 4 ' ')) tp) ^
        (Printf.sprintf "%s\"col\": %d,\n" (indent ^ (String.make 4 ' ')) idx) ^
          (Printf.sprintf "%s\"db\": %s\n" (indent ^ (String.make 4 ' ')) (Db.to_json db)) ^
            (Printf.sprintf "%s}" indent)

  let to_json tp db f =
    let preds_row = row tp db f in
    (Printf.sprintf "%s\"dbs_row\": [\n" (String.make 8 ' ')) ^
      (String.concat ~sep:",\n" (List.map preds_row ~f:(fun (tp, idx, db) ->
                                     cell_to_json (String.make 8 ' ') tp idx db))) ^
        (Printf.sprintf "]")

end

module Expl = struct

  (* TODO: Rename types and functions in this module *)

  type cell = timepoint * int * (Interval.t * period) option * kind
  and kind =
    Boolean of bool
  | Assignment of string * string * bool
  | Partition of string * (string * (cell * cell list) list) list

  type cell_row = (cell * cell list) list

  type cell_expl = Leaf of bool * cell_row | Expl of string * (string * cell_expl) list

  let boolean = function
    | Boolean s -> s
    | _ -> raise (Invalid_argument "this function is not defined for assignment/partition kinds")

  let string_of_kind = function
    | Boolean _ -> "boolean"
    | Assignment _ -> "assignment"
    | Partition _ -> "partition"

  let cell_kind = function
    | (_, _, _, k) -> string_of_kind k

  let rec cell_idx idx = function
    | Formula.TT | FF | EqConst _ | Predicate _ -> idx
    | Neg f' | Exists (_, f') | Forall (_, f')
      | Prev (_, f') | Next (_, f')
      | Once (_, f') | Eventually (_, f')
      | Historically (_, f') | Always (_, f') -> cell_idx (idx+1) f'
    | And (f1, f2) | Or (f1, f2)
      | Imp (f1, f2) | Iff (f1, f2)
      | Since (_, f1, f2) | Until (_, f1, f2) -> let idx' = cell_idx (idx+1) f1 in
                                                 cell_idx (idx'+1) f2

  (* Table conversion for strict subformulas                                 *)
  (*                                                                         *)
  (* skip indicates that the previous recursive call comes from, e.g., SOrL, *)
  (* which means that the next index should be incremented by 1              *)

  let rec ssubfs_cell_row row idx skip (f: Formula.t) (p: Expl.Proof.t) : (cell_row * int) =
    match f, p with
    | TT, S (STT _) ->
       let cell = (Expl.Proof.p_at p, idx, None, Boolean true) in
       let idx = if skip then idx+1 else idx in
       ((cell, []) :: row, idx)
    | EqConst _, S (SEqConst _) ->
       let cell = (Expl.Proof.p_at p, idx, None, Boolean true) in
       let idx = if skip then idx+1 else idx in
       ((cell, []) :: row, idx)
    | Predicate _, S (SPred _) ->
       let cell = (Expl.Proof.p_at p, idx, None, Boolean true) in
       let idx = if skip then idx+1 else idx in
       ((cell, []) :: row, idx)
    | Neg f', S (SNeg vp) ->
       let vp_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row vp_idx false f' (V vp) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean true) in
       let cells = [(Expl.Proof.v_at vp, vp_idx, None, Boolean false)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Or (f1, _), S (SOrL sp1) ->
       let sp1_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row sp1_idx true f1 (S sp1) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean true) in
       let cells = [(Expl.Proof.s_at sp1, sp1_idx, None, Boolean true)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Or (f1, f2), S (SOrR sp2) ->
       let sp1_idx = idx+1 in
       let sp2_idx = (cell_idx sp1_idx f1)+1 in
       let (row', idx') = ssubfs_cell_row row sp2_idx false f2 (S sp2) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean true) in
       let cells = [(Expl.Proof.s_at sp2, sp2_idx, None, Boolean true)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | And (f1, f2), S (SAnd (sp1, sp2)) ->
       let sp1_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row sp1_idx false f1 (S sp1) in
       let sp2_idx = idx'+1 in
       let (tbl'', idx'') = ssubfs_cell_row row' sp2_idx false f2 (S sp2) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean true) in
       let cells = [(Expl.Proof.s_at sp1, sp1_idx, None, Boolean true);
                    (Expl.Proof.s_at sp2, sp2_idx, None, Boolean true)] in
       let idx'' = if skip then idx''+1 else idx'' in
       ((cell, cells) :: tbl'', idx'')
    | Imp (f1, f2), S (SImpL (vp1)) ->
       let vp1_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row vp1_idx true f1 (V vp1) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean true) in
       let cells = [(Expl.Proof.v_at vp1, vp1_idx, None, Boolean false)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Imp (f1, f2), S (SImpR (sp2)) ->
       let sp1_idx = idx+1 in
       let sp2_idx = (cell_idx sp1_idx f1)+1 in
       let (row', idx') = ssubfs_cell_row row sp2_idx false f2 (S sp2) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean true) in
       let cells = [(Expl.Proof.s_at sp2, sp2_idx, None, Boolean true)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Iff (f1, f2), S (SIffSS (sp1, sp2)) ->
       let sp1_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row sp1_idx false f1 (S sp1) in
       let sp2_idx = idx'+1 in
       let (tbl'', idx'') = ssubfs_cell_row row' sp2_idx false f2 (S sp2) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean true) in
       let cells = [(Expl.Proof.s_at sp1, sp1_idx, None, Boolean true);
                    (Expl.Proof.s_at sp2, sp2_idx, None, Boolean true)] in
       let idx'' = if skip then idx''+1 else idx'' in
       ((cell, cells) :: tbl'', idx'')
    | Iff (f1, f2), S (SIffVV (vp1, vp2)) ->
       let vp1_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row vp1_idx false f1 (V vp1) in
       let vp2_idx = idx'+1 in
       let (tbl'', idx'') = ssubfs_cell_row row' vp2_idx false f2 (V vp2) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean true) in
       let cells = [(Expl.Proof.v_at vp1, vp1_idx, None, Boolean false);
                    (Expl.Proof.v_at vp2, vp2_idx, None, Boolean false)] in
       let idx'' = if skip then idx''+1 else idx'' in
       ((cell, cells) :: tbl'', idx'')
    | Exists (_, f'), S (SExists (x, d, sp)) ->
       let sp_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row sp_idx false f' (S sp) in
       let cell = (Expl.Proof.p_at p, idx, None, Assignment (x, Domain.to_string d, true)) in
       let cells = [(Expl.Proof.s_at sp, sp_idx, None, Boolean true)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Forall (_, f'), S (SForall (x, part)) ->
       let sps_idx = idx+1 in
       let row' = List.filter row ~f:(fun (cell, _) -> not (String.equal (cell_kind cell) "partition")) in
       let (idx', part_tbl) = List.fold_map part ~init:sps_idx ~f:(fun i (s, sp) ->
                                  let (row', i') = ssubfs_cell_row row' sps_idx false f' (S sp) in
                                  let cell = (Expl.Proof.p_at p, idx, None, Boolean true) in
                                  let cells = [(Expl.Proof.s_at sp, sps_idx, None, Boolean true)] in
                                  let i' = if skip then i'+1 else i' in
                                  (max i i', (Setc.to_json s, (cell, cells) :: row'))) in
       let part = Partition (x, part_tbl) in
       let cell = (Expl.Proof.p_at p, idx, None, part) in
       ((cell, []) :: row, idx')
    | Prev (i, f'), S (SPrev sp)
      | Once (i, f'), S (SOnce (_, sp))
      | Next (i, f'), S (SNext sp)
      | Eventually (i, f'), S (SEventually (_, sp)) ->
       let sp_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row sp_idx false f' (S sp) in
       let cell = match f with Prev _
                             | Once _ -> (Expl.Proof.p_at p, idx, Some(i, PAST), Boolean true)
                             | Next _
                               | Eventually _ -> (Expl.Proof.p_at p, idx, Some(i, FUTURE), Boolean true)
                             | _ -> raise (Invalid_argument "unexpected proof constructor") in
       let cells = [(Expl.Proof.s_at sp, sp_idx, None, Boolean true)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Historically (i, f'), S (SHistorically (_, _, sps))
      | Always (i, f'), S (SAlways (_, _, sps)) ->
       let sps_idx = idx+1 in
       let (row', idx') = Fdeque.fold sps ~init:(row, sps_idx)
                            ~f:(fun (t, _) sp -> ssubfs_cell_row t sps_idx false f' (S sp)) in
       let cell = match f with Historically _ -> (Expl.Proof.p_at p, idx, Some(i, PAST), Boolean true)
                             | Always _ -> (Expl.Proof.p_at p, idx, Some(i, FUTURE), Boolean true)
                             | _ -> raise (Invalid_argument "unexpected proof constructor") in
       let cells = Fdeque.to_list (Fdeque.map sps ~f:(fun sp -> (Expl.Proof.s_at sp, sps_idx, None, Boolean true))) in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Since (i, f1, f2), S (SSince (sp2, sp1s))
      | Until (i, f1, f2), S (SUntil (sp2, sp1s)) when Fdeque.is_empty sp1s ->
       let sp1_idx = idx+1 in
       (* Recursive calls *)
       let sp2_idx = (cell_idx sp1_idx f1)+1 in
       let (row', idx') = ssubfs_cell_row row sp2_idx false f2 (S sp2) in
       (* State update *)
       let cell = match f with Since _ -> (Expl.Proof.p_at p, idx, Some(i, PAST), Boolean true)
                             | Until _ -> (Expl.Proof.p_at p, idx, Some(i, FUTURE), Boolean true)
                             | _ -> raise (Invalid_argument "unexpected proof constructor") in
       let cells = [(Expl.Proof.s_at sp2, sp2_idx, None, Boolean true)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Since (i, f1, f2), S (SSince (sp2, sp1s))
      | Until (i, f1, f2), S (SUntil (sp2, sp1s)) ->
       let sp1_idx = idx+1 in
       (* Recursive calls *)
       let (row', idx') = Fdeque.fold sp1s ~init:(row, sp1_idx)
                            ~f:(fun (t, _) sp1 -> ssubfs_cell_row t sp1_idx false f1 (S sp1)) in
       let sp2_idx = idx'+1 in
       let (tbl'', idx'') = ssubfs_cell_row row' sp2_idx false f2 (S sp2) in
       (* State update *)
       let cell = match f with Since _ -> (Expl.Proof.p_at p, idx, Some(i, PAST), Boolean true)
                             | Until _ -> (Expl.Proof.p_at p, idx, Some(i, FUTURE), Boolean true)
                             | _ -> raise (Invalid_argument "unexpected proof constructor") in
       let cells = (Expl.Proof.s_at sp2, sp2_idx, None, Boolean true) ::
                     (Fdeque.to_list (Fdeque.map sp1s ~f:(fun sp1 ->
                                          (Expl.Proof.s_at sp1, sp1_idx, None, Boolean true)))) in
       let idx'' = if skip then idx''+1 else idx'' in
       ((cell, cells) :: tbl'', idx'')
    | FF, V (VFF _) ->
       let cell = (Expl.Proof.p_at p, idx, None, Boolean false) in
       let idx = if skip then idx+1 else idx in
       ((cell, []) :: row, idx)
    | EqConst _, V (VEqConst _) ->
       let cell = (Expl.Proof.p_at p, idx, None, Boolean false) in
       let idx = if skip then idx+1 else idx in
       ((cell, []) :: row, idx)
    | Predicate _, V (VPred _) ->
       let cell = (Expl.Proof.p_at p, idx, None, Boolean false) in
       let idx = if skip then idx+1 else idx in
       ((cell, []) :: row, idx)
    | Neg f', V (VNeg sp) ->
       let sp_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row sp_idx false f' (S sp) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean false) in
       let cells = [(Expl.Proof.s_at sp, sp_idx, None, Boolean true)] in
       ((cell, cells) :: row', idx')
    | Or (f1, f2), V (VOr (vp1, vp2)) ->
       let vp1_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row vp1_idx false f1 (V vp1) in
       let vp2_idx = idx'+1 in
       let (tbl'', idx'') = ssubfs_cell_row row' vp2_idx false f2 (V vp2) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean false) in
       let cells = [(Expl.Proof.v_at vp1, vp1_idx, None, Boolean false);
                    (Expl.Proof.v_at vp2, vp2_idx, None, Boolean false)] in
       let idx'' = if skip then idx''+1 else idx'' in
       ((cell, cells) :: tbl'', idx'')
    | And (f1, _), V (VAndL vp1) ->
       let vp1_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row vp1_idx true f1 (V vp1) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean false) in
       let cells = [(Expl.Proof.v_at vp1, vp1_idx, None, Boolean false)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | And (f1, f2), V (VAndR vp2) ->
       let vp1_idx = idx+1 in
       let vp2_idx = (cell_idx vp1_idx f1)+1 in
       let (row', idx') = ssubfs_cell_row row vp2_idx false f2 (V vp2) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean false) in
       let cells = [(Expl.Proof.v_at vp2, vp2_idx, None, Boolean false)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Imp (f1, f2), V (VImp (sp1, vp2))
      | Iff (f1, f2), V (VIffSV (sp1, vp2)) ->
       let sp1_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row sp1_idx false f1 (S sp1) in
       let vp2_idx = idx'+1 in
       let (tbl'', idx'') = ssubfs_cell_row row' vp2_idx false f2 (V vp2) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean false) in
       let cells = [(Expl.Proof.s_at sp1, sp1_idx, None, Boolean true);
                    (Expl.Proof.v_at vp2, vp2_idx, None, Boolean false)] in
       let idx'' = if skip then idx''+1 else idx'' in
       ((cell, cells) :: tbl'', idx'')
    | Iff (f1, f2), V (VIffVS (vp1, sp2)) ->
       let vp1_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row vp1_idx false f1 (V vp1) in
       let sp2_idx = idx'+1 in
       let (tbl'', idx'') = ssubfs_cell_row row' sp2_idx false f2 (S sp2) in
       let cell = (Expl.Proof.p_at p, idx, None, Boolean false) in
       let cells = [(Expl.Proof.v_at vp1, vp1_idx, None, Boolean false);
                    (Expl.Proof.s_at sp2, sp2_idx, None, Boolean true)] in
       let idx'' = if skip then idx''+1 else idx'' in
       ((cell, cells) :: tbl'', idx'')
    | Exists (_, f'), V (VExists (x, part)) ->
       let vps_idx = idx+1 in
       let row' = List.filter row ~f:(fun (cell, _) -> not (String.equal (cell_kind cell) "partition")) in
       let (idx', part_tbl) = List.fold_map part ~init:vps_idx ~f:(fun i (s, vp) ->
                                  let (row', i') = ssubfs_cell_row row' vps_idx false f' (V vp) in
                                  let cell = (Expl.Proof.p_at p, idx, None, Boolean false) in
                                  let cells = [(Expl.Proof.v_at vp, vps_idx, None, Boolean false)] in
                                  let i' = if skip then i'+1 else i' in
                                  (max i i', (Setc.to_json s, (cell, cells) :: row'))) in
       let part = Partition (x, part_tbl) in
       let cell = (Expl.Proof.p_at p, idx, None, part) in
       ((cell, []) :: row, idx')
    | Forall (_, f'), V (VForall (x, d, vp)) ->
       let vp_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row vp_idx false f' (V vp) in
       let cell = (Expl.Proof.p_at p, idx, None, Assignment (x, Domain.to_string d, false)) in
       let cells = [(Expl.Proof.v_at vp, vp_idx, None, Boolean false)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Prev (i, f'), V (VPrev vp)
      | Historically (i, f'), V (VHistorically (_, vp))
      | Next (i, f'), V (VNext vp)
      | Always (i, f'), V (VAlways (_, vp)) ->
       let vp_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row vp_idx false f' (V vp) in
       let cell = match f with Prev _
                             | Historically _ -> (Expl.Proof.p_at p, idx, Some(i, PAST), Boolean false)
                             | Always _
                               | Next _ -> (Expl.Proof.p_at p, idx, Some(i, FUTURE), Boolean false)
                             | _ -> raise (Invalid_argument "unexpected proof constructor") in
       let cells = [(Expl.Proof.v_at vp, vp_idx, None, Boolean false)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Once (i, f'), V (VOnce (_, _, vps))
      | Eventually (i, f'), V (VEventually (_, _, vps)) ->
       let vps_idx = idx+1 in
       let (row', idx') = Fdeque.fold vps ~init:(row, vps_idx)
                            ~f:(fun (t, _) vp -> ssubfs_cell_row t vps_idx false f' (V vp)) in
       let cell = match f with Once _ -> (Expl.Proof.p_at p, idx, Some(i, PAST), Boolean false)
                             | Eventually _ -> (Expl.Proof.p_at p, idx, Some(i, FUTURE), Boolean false)
                             | _ -> raise (Invalid_argument "unexpected proof constructor") in
       let cells = Fdeque.to_list (Fdeque.map vps ~f:(fun vp -> (Expl.Proof.v_at vp, vps_idx, None, Boolean false))) in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Since (i, f1, _), V (VSince (_, vp1, vp2s))
      | Until (i, f1, _), V (VUntil (_, vp1, vp2s)) when Fdeque.is_empty vp2s ->
       let vp1_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row vp1_idx false f1 (V vp1) in
       let cell = match f with Since _ -> (Expl.Proof.p_at p, idx, Some(i, PAST), Boolean false)
                             | Until _ -> (Expl.Proof.p_at p, idx, Some(i, FUTURE), Boolean false)
                             | _ -> raise (Invalid_argument "unexpected proof constructor") in
       let cells = [(Expl.Proof.v_at vp1, vp1_idx, None, Boolean false)] in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Since (i, f1, f2), V (VSince (_, vp1, vp2s))
      | Until (i, f1, f2), V (VUntil (_, vp1, vp2s)) ->
       let vp1_idx = idx+1 in
       let (row', idx') = ssubfs_cell_row row vp1_idx false f1 (V vp1) in
       let vp2_idx = idx'+1 in
       let (tbl'', idx'') = Fdeque.fold vp2s ~init:(row', vp2_idx)
                              ~f:(fun (t, _) vp2 -> ssubfs_cell_row t vp2_idx false f2 (V vp2)) in
       let cell = match f with Since _ -> (Expl.Proof.p_at p, idx, Some(i, PAST), Boolean false)
                             | Until _ -> (Expl.Proof.p_at p, idx, Some(i, FUTURE), Boolean false)
                             | _ -> raise (Invalid_argument "unexpected proof constructor") in
       let cells = (Expl.Proof.v_at vp1, vp1_idx, None, Boolean false) ::
                     (Fdeque.to_list (Fdeque.map vp2s ~f:(fun vp2 ->
                                          (Expl.Proof.v_at vp2, vp2_idx, None, Boolean false)))) in
       let idx'' = if skip then idx''+1 else idx'' in
       ((cell, cells) :: tbl'', idx'')
    | Since (i, f1, f2), V (VSinceInf (_, _, vp2s))
      | Until (i, f1, f2), V (VUntilInf (_, _, vp2s)) ->
       let vp1_idx = idx+1 in
       let vp2_idx = (cell_idx vp1_idx f1)+1 in
       let (row', idx') = Fdeque.fold vp2s ~init:(row, vp2_idx)
                            ~f:(fun (t, _) vp2 -> ssubfs_cell_row t vp2_idx false f2 (V vp2)) in
       let cell = match f with Since _ -> (Expl.Proof.p_at p, idx, Some(i, PAST), Boolean false)
                             | Until _ -> (Expl.Proof.p_at p, idx, Some(i, FUTURE), Boolean false)
                             | _ -> raise (Invalid_argument "unexpected proof constructor") in
       let cells = Fdeque.to_list (Fdeque.map vp2s ~f:(fun vp2 -> (Expl.Proof.v_at vp2, vp2_idx, None, Boolean false))) in
       let idx' = if skip then idx'+1 else idx' in
       ((cell, cells) :: row', idx')
    | Historically (_, _), S (SHistoricallyOut _)
      | Once (_, _), V (VOnceOut _)
      | Prev (_, _), V VPrev0
      | Prev (_, _), V (VPrevOutL _)
      | Prev (_, _), V (VPrevOutR _)
      | Next (_, _), V (VNextOutL _)
      | Next (_, _), V (VNextOutR _)
      | Since (_, _, _), V (VSinceOut _) ->
       let cell = (Expl.Proof.p_at p, idx, None, Boolean false) in
       let idx = if skip then idx+1 else idx in
       ((cell, []) :: row, idx)
    | _ -> raise (Invalid_argument "invalid formula/proof pair")

  let rec expl_cell row idx (f: Formula.t) (expl: Expl.t) : cell_expl = match expl with
    | Expl.Pdt.Leaf pt -> Leaf (Expl.Proof.isS pt, (fst (ssubfs_cell_row row idx false f pt)))
    | Node (x, part) -> Expl (x, List.map (List.rev part) ~f:(fun (s, e) -> (Setc.to_json s, expl_cell row idx f e)))

  let inner_cells_to_json indent cells =
    if List.is_empty cells then " []"
    else ((Printf.sprintf " [\n") ^
            (String.concat ~sep:",\n"
               (List.map cells ~f:(fun (tp, col, _, kind) ->
                    (Printf.sprintf "%s{\n" (indent ^ (String.make 4 ' '))) ^
                      (Printf.sprintf "%s\"tp\": %d,\n" (indent ^ (String.make 8 ' ')) tp) ^
                        (Printf.sprintf "%s\"col\": %d,\n" (indent ^ (String.make 8 ' ')) col) ^
                          (Printf.sprintf "%s\"bool\": %b\n" (indent ^ (String.make 8 ' ')) (boolean kind)) ^
                            (Printf.sprintf "%s}" (indent ^ (String.make 4 ' '))))))) ^ (Printf.sprintf "]\n")

  let rec cell_to_json indent (tp, col, ip_opt, kind) cells =
    (Printf.sprintf "%s{\n" indent) ^
      (Printf.sprintf "%s\"tp\": %d,\n" (indent ^ (String.make 4 ' ')) tp) ^
        (Printf.sprintf "%s\"col\": %d,\n" (indent ^ (String.make 4 ' ')) col) ^
          (if Option.is_none ip_opt then ""
           else (let (i, p) = Option.value_exn ip_opt in
                 Printf.sprintf "%s\"interval\": \"%s\",\n" (indent ^ (String.make 12 ' ')) (Interval.to_string i) ^
                   (match p with
                    | PAST -> Printf.sprintf "%s\"period\": \"past\",\n" (indent ^ (String.make 12 ' '))
                    | FUTURE -> Printf.sprintf "%s\"period\": \"future\",\n" (indent ^ (String.make 12 ' '))))) ^
            (match kind with
             | Boolean b ->
                (Printf.sprintf "%s\"kind\": \"boolean\",\n" (indent ^ (String.make 4 ' '))) ^
                  (Printf.sprintf "%s\"bool\": \"%b\",\n" (indent ^ (String.make 4 ' ')) b) ^
                    (Printf.sprintf "%s\"cells\":" (indent ^ (String.make 4 ' '))) ^
                      (inner_cells_to_json indent cells)
             | Assignment (x, d, b) ->
                (Printf.sprintf "%s\"kind\": \"assignment\",\n" (indent ^ (String.make 4 ' '))) ^
                  (Printf.sprintf "%s\"var\": \"%s\",\n" (indent ^ (String.make 4 ' ')) x) ^
                    (Printf.sprintf "%s\"value\": \"%s\",\n" (indent ^ (String.make 4 ' ')) d) ^
                      (Printf.sprintf "%s\"bool\": \"%b\",\n" (indent ^ (String.make 4 ' ')) b) ^
                        (Printf.sprintf "%s\"cells\":" (indent ^ (String.make 4 ' '))) ^
                          (inner_cells_to_json indent cells)
             | Partition (x, part_tbl) ->
                (Printf.sprintf "%s\"var\": \"%s\",\n" (indent ^ (String.make 4 ' ')) x) ^
                  (Printf.sprintf "%s\"kind\": \"partition\",\n" (indent ^ (String.make 4 ' '))) ^
                    (Printf.sprintf "%s\"part\": [\n" (indent ^ (String.make 4 ' '))) ^
                      (String.concat ~sep:",\n"
                         (List.map (List.rev part_tbl) ~f:(fun (sub, c_row) ->
                              Printf.sprintf "%s{\n" (indent ^ (String.make 4 ' ')) ^
                                (Printf.sprintf "%s%s\n" (indent ^ (String.make 8 ' ')) sub) ^
                                  (Printf.sprintf "%s\"table\": [\n" (indent ^ (String.make 12 ' '))) ^
                                    String.concat ~sep:",\n"
                                      (List.map c_row ~f:(fun (c, cs) ->
                                           cell_to_json (indent ^ (String.make 8 ' ')) c cs)) ^
                                      (Printf.sprintf "\n%s]\n" (indent ^ (String.make 12 ' '))) ^
                                        (Printf.sprintf "%s}" (indent ^ (String.make 4 ' ')))))) ^
                        (Printf.sprintf "]\n")) ^
              (Printf.sprintf "\n%s}" indent)

  let rec e_cell_to_json indent = function
    | Leaf (b, c_row) ->
       (Printf.sprintf "%s\"type\": \"leaf\",\n" (indent ^ (String.make 4 ' '))) ^
         (Printf.sprintf "%s\"table\": [\n" (indent ^ (String.make 4 ' '))) ^
           String.concat ~sep:",\n"
             (List.map c_row ~f:(fun (c, cs) ->
                  cell_to_json (indent ^ (String.make 4 ' ')) c cs)) ^
             (Printf.sprintf "\n%s]\n" (indent ^ (String.make 4 ' ')))
    | Expl (x, ces) ->
         (Printf.sprintf "%s\"type\": \"node\",\n" (indent ^ (String.make 4 ' '))) ^
           (Printf.sprintf "%s\"var\": \"%s\",\n" (indent ^ (String.make 4 ' ')) x) ^
             (Printf.sprintf "%s\"part\": [\n" (indent ^ (String.make 4 ' '))) ^
               (String.concat ~sep:",\n"
                  (List.map ces ~f:(fun (sub, e) ->
                       Printf.sprintf "%s{\n" (indent ^ (String.make 4 ' ')) ^
                         (Printf.sprintf "%s%s\n" (indent ^ (String.make 8 ' ')) sub) ^
                           (e_cell_to_json (indent ^ (String.make 4 ' ')) e) ^
                             Printf.sprintf "%s}" (indent ^ (String.make 4 ' '))))) ^
                 (Printf.sprintf "]\n")

let to_json (f: Formula.t) (expl: Expl.t) =
  let c_e = expl_cell [] 0 f expl in
  e_cell_to_json (String.make 8 ' ') c_e

end
