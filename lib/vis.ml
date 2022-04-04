(*******************************************************************)
(*     This is part of Explanator2, it is distributed under the    *)
(*     terms of the GNU Lesser General Public License version 3    *)
(*           (see file LICENSE for more details)                   *)
(*                                                                 *)
(*  Copyright 2022:                                                *)
(*  Leonardo Lima (UCPH)                                           *)
(*******************************************************************)

open Mtl
open Expl
open Util

module List = Base.List

type idx = int
type cell = timepoint * idx * bool
type table = (cell * (cell list)) list

let rec f_idx idx f =
  match f with
  | TT -> idx
  | FF -> idx
  | P _ -> idx
  | Neg f' | Prev (_, f') | Next (_, f') -> f_idx (idx+1) f'
  | Conj (f1, f2) | Disj (f1, f2)
  | Since (_, f1, f2) | Until (_, f1, f2) -> let idx' = f_idx (idx+1) f1 in
                                             f_idx (idx'+1) f2

let rec update_state tbl idx f p =
  match f, p with
  | TT, S (STT i) ->
     let cell = (p_at p, idx, true) in
     ((cell, []) :: tbl, idx)
  | P s1, S (SAtom (i, s2)) ->
     let cell = (p_at p, idx, true) in
     ((cell, []) :: tbl, idx)
  | Neg f', S (SNeg vp) ->
     let vp_idx = idx+1 in
     let (tbl', idx') = update_state tbl vp_idx f' (V vp) in
     let cell = (p_at p, idx, true) in
     let cells = [(v_at vp, vp_idx, false)] in
     ((cell, cells) :: tbl', idx')
  | Disj (f1, _), S (SDisjL sp1) ->
     let sp1_idx = idx+1 in
     let (tbl', idx') = update_state tbl sp1_idx f1 (S sp1) in
     let cell = (p_at p, idx, true) in
     let cells = [(s_at sp1, sp1_idx, true)] in
     ((cell, cells) :: tbl', idx')
  | Disj (f1, f2), S (SDisjR sp2) ->
     let sp1_idx = idx+1 in
     let sp2_idx = (f_idx sp1_idx f1)+1 in
     let (tbl', idx') = update_state tbl sp2_idx f2 (S sp2) in
     let cell = (p_at p, idx, true) in
     let cells = [(s_at sp2, sp2_idx, true)] in
     ((cell, cells) :: tbl', idx')
  | Conj (f1, f2), S (SConj (sp1, sp2)) ->
     let sp1_idx = idx+1 in
     let (tbl', idx') = update_state tbl sp1_idx f1 (S sp1) in
     let sp2_idx = idx'+1 in
     let (tbl'', idx'') = update_state tbl' sp2_idx f2 (S sp2) in
     let cell = (p_at p, idx, true) in
     let cells = [(s_at sp1, sp1_idx, true); (s_at sp2, sp2_idx, true)] in
     ((cell, cells) :: tbl'', idx'')
  | Prev (_, f'), S (SPrev sp) ->
     let sp_idx = idx+1 in
     let (tbl', idx') = update_state tbl sp_idx f' (S sp) in
     let cell = (p_at p, idx, true) in
     let cells = [(s_at sp, sp_idx, true)] in
     ((cell, cells) :: tbl', idx')
  | Since (_, f1, f2), S (SSince (sp2, []))
  | Until (_, f1, f2), S (SUntil (sp2, [])) ->
     let sp1_idx = idx+1 in
     (* Recursive calls *)
     let sp2_idx = (f_idx sp1_idx f1)+1 in
     let (tbl', idx') = update_state tbl sp2_idx f2 (S sp2) in
     (* State update *)
     let cell = (p_at p, idx, true) in
     let cells = [(s_at sp2, sp2_idx, true)] in
     ((cell, cells) :: tbl', idx')
  | Since (_, f1, f2), S (SSince (sp2, sp1s))
  | Until (_, f1, f2), S (SUntil (sp2, sp1s)) ->
     let sp1_idx = idx+1 in
     (* Recursive calls *)
     let (tbl', idx') = List.fold sp1s ~init:(tbl, sp1_idx)
                          ~f:(fun (t, i) sp1 -> update_state t i f1 (S sp1)) in
     let sp2_idx = idx'+1 in
     let (tbl'', idx'') = update_state tbl' sp2_idx f2 (S sp2) in
     (* State update *)
     let cell = (p_at p, idx, true) in
     let cells = (s_at sp2, sp2_idx, true) ::
                   (List.map sp1s ~f:(fun sp1 -> (s_at sp1, sp1_idx, true))) in
     ((cell, cells) :: tbl'', idx'')
  | FF, V (VFF i) ->
     let cell = (p_at p, idx, false) in
     ((cell, []) :: tbl, idx)
  | P s1, V (VAtom (i, s2)) ->
     let cell = (p_at p, idx, false) in
     ((cell, []) :: tbl, idx)
  | Neg f', V (VNeg sp) ->
     let sp_idx = idx+1 in
     let (tbl', idx') = update_state tbl sp_idx f' (S sp) in
     let cell = (p_at p, idx, false) in
     let cells = [(s_at sp, sp_idx, true)] in
     ((cell, cells) :: tbl', idx')
  | Disj (f1, f2), V (VDisj (vp1, vp2)) ->
     let vp1_idx = idx+1 in
     let (tbl', idx') = update_state tbl vp1_idx f1 (V vp1) in
     let vp2_idx = idx'+1 in
     let (tbl'', idx'') = update_state tbl' vp2_idx f2 (V vp2) in
     let cell = (p_at p, idx, false) in
     let cells = [(v_at vp1, vp1_idx, false); (v_at vp2, vp2_idx, false)] in
     ((cell, cells) :: tbl'', idx'')
  | Conj (f1, _), V (VConjL vp1) ->
     let vp1_idx = idx+1 in
     let (tbl', idx') = update_state tbl vp1_idx f1 (V vp1) in
     let cell = (p_at p, idx, false) in
     let cells = [(v_at vp1, vp1_idx, false)] in
     ((cell, cells) :: tbl', idx')
  | Conj (f1, f2), V (VConjR vp2) ->
     let vp1_idx = idx+1 in
     let vp2_idx = (f_idx vp1_idx f1)+1 in
     let (tbl', idx') = update_state tbl vp2_idx f2 (V vp2) in
     let cell = (p_at p, idx, false) in
     let cells = [(v_at vp2, vp2_idx, false)] in
     ((cell, cells) :: tbl', idx')
  | Next (_, f'), V (VNext vp)
  | Prev (_, f'), V (VPrev vp) ->
     let vp_idx = idx+1 in
     let (tbl', idx') = update_state tbl vp_idx f' (V vp) in
     let cell = (p_at p, idx, false) in
     let cells = [(v_at vp, vp_idx, false)] in
     ((cell, cells) :: tbl', idx')
  | Since (_, f1, _), V (VSince (_, vp1, []))
  | Until (_, f1, _), V (VUntil (_, vp1, [])) ->
     let vp1_idx = idx+1 in
     let (tbl', idx') = update_state tbl vp1_idx f1 (V vp1) in
     let cell = (p_at p, idx, false) in
     let cells = [(v_at vp1, vp1_idx, false)] in
     ((cell, cells) :: tbl', idx')
  | Since (_, f1, f2), V (VSince (_, vp1, vp2s))
  | Until (_, f1, f2), V (VUntil (_, vp1, vp2s)) ->
     let vp1_idx = idx+1 in
     let (tbl', idx') = update_state tbl vp1_idx f1 (V vp1) in
     let vp2_idx = idx'+1 in
     let (tbl'', idx'') = List.fold vp2s ~init:(tbl, vp2_idx)
                            ~f:(fun (t, i) vp2 -> update_state t i f2 (V vp2)) in
     let cell = (p_at p, idx, false) in
     let cells = (v_at vp1, vp1_idx, false) ::
                   (List.map vp2s ~f:(fun vp2 -> (v_at vp2, vp2_idx, false))) in
     ((cell, cells) :: tbl'', idx'')
  | Since (_, f1, f2), V (VSinceInf (_, _, vp2s))
  | Until (_, f1, f2), V (VUntilInf (_, _, vp2s)) ->
     let vp1_idx = idx+1 in
     let vp2_idx = (f_idx vp1_idx f1)+1 in
     let (tbl', idx') = List.fold vp2s ~init:(tbl, vp2_idx)
                          ~f:(fun (t, i) vp2 -> update_state t i f2 (V vp2)) in
     let cell = (p_at p, idx, false) in
     let cells = List.map vp2s ~f:(fun vp2 -> (v_at vp2, vp2_idx, false)) in
     ((cell, cells) :: tbl', idx')
  | Prev (_, _), V VPrev0
  | Prev (_, _), V (VPrevOutL _)
  | Prev (_, _), V (VPrevOutR _)
  | Next (_, _), V (VNextOutL _)
  | Next (_, _), V (VNextOutR _)
  | Since (_, _, _), V (VSinceOutL _) ->
     (tbl, idx)

let cell_to_json (tp, col, b) cells =
  let ident = "    " in
  let ident2 = "    " ^ ident in
  let ident3 = "    " ^ ident2 in
  (Printf.sprintf "%s{\n" ident) ^
  (Printf.sprintf "%s\"tp\": %d,\n" ident2 tp) ^
  (Printf.sprintf "%s\"col\": %d,\n" ident2 col) ^
  (Printf.sprintf "%s\"bool\": %B,\n" ident2 b) ^
  (Printf.sprintf "%s\"cells\":" ident2) ^
  (if List.is_empty cells then " []"
   else ((Printf.sprintf " [\n") ^
         (String.concat ",\n" (List.map cells ~f:(fun (tp', col', b') ->
                                   (Printf.sprintf "%s{\n" ident2) ^
                                   (Printf.sprintf "%s\"tp\": %d,\n" ident3 tp') ^
                                   (Printf.sprintf "%s\"col\": %d,\n" ident3 col') ^
                                   (Printf.sprintf "%s\"bool\": %B\n" ident3 b') ^
                                   (Printf.sprintf "%s}" ident2)))) ^
         (Printf.sprintf "]\n"))) ^
  (Printf.sprintf "\n%s}" ident)

let expl_to_json f p =
  (* (Printf.printf "f = %s\n" (formula_to_string f));
   * (Printf.printf "p = %s\n" (expl_to_string p)); *)
  let (tbl, _) = update_state [] 0 f p in
  let ident = "    " in
  (Printf.sprintf "%s\"table\": [\n" ident) ^
  (String.concat ",\n" (List.map tbl ~f:(fun (cell, cells) -> cell_to_json cell cells))) ^
  (Printf.sprintf "]")