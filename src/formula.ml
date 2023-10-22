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

type t =
  | TT
  | FF
  | EqConst of string * Dom.t
  | Predicate of string * Term.t list
  | Neg of t
  | And of t * t
  | Or of t * t
  | Imp of t * t
  | Iff of t * t
  | Exists of string * t
  | Forall of string * t
  | Prev of Interval.t * t
  | Next of Interval.t * t
  | Once of Interval.t * t
  | Eventually of Interval.t * t
  | Historically of Interval.t * t
  | Always of Interval.t * t
  | Since of Interval.t * t * t
  | Until of Interval.t * t * t

let tt = TT
let ff = FF
let eqconst x d = EqConst (x, d)
let predicate p_name trms = Predicate (p_name, check_terms p_name trms)
let neg f = Neg f
let conj f g = And (f, g)
let disj f g = Or (f, g)
let imp f g = Imp (f, g)
let iff f g = Iff (f, g)
let exists x f = Exists (x, f)
let forall x f = Forall (x, f)
let prev i f = Prev (i, f)
let next i f = Next (i, f)
let once i f = Once (i, f)
let eventually i f = Eventually (i, f)
let historically i f = Historically (i, f)
let always i f = Always (i, f)
let since i f g = Since (i, f, g)
let until i f g = Until (i, f, g)

(* Rewriting of non-native operators *)
let trigger i f g = Neg (Since (i, Neg (f), Neg (g)))
let release i f g = Neg (Until (i, Neg (f), Neg (g)))

let equal x y = match x, y with
  | TT, TT | FF, FF -> true
  | EqConst (x, c), EqConst (x', c') -> String.equal x x'
  | Predicate (r, trms), Predicate (r', trms') -> String.equal r r' && List.equal Term.equal trms trms'
  | Neg f, Neg f' -> phys_equal f f'
  | And (f, g), And (f', g')
    | Or (f, g), Or (f', g')
    | Imp (f, g), Imp (f', g')
    | Iff (f, g), Iff (f', g') -> phys_equal f f' && phys_equal g g'
  | Exists (x, f), Exists (x', f')
    | Forall (x, f), Forall (x', f') -> String.equal x x' && phys_equal f f'
  | Prev (i, f), Prev (i', f')
    | Next (i, f), Next (i', f')
    | Once (i, f), Once (i', f')
    | Eventually (i, f), Eventually (i', f')
    | Historically (i, f), Historically (i', f')
    | Always (i, f), Always (i', f') -> Interval.equal i i' && phys_equal f f'
  | Since (i, f, g), Since (i', f', g')
    | Until (i, f, g), Until (i', f', g') -> Interval.equal i i' && phys_equal f f' && phys_equal g g'
  | _ -> false

let rec fv = function
  | TT | FF -> Set.empty (module String)
  | EqConst (x, c) -> Set.of_list (module String) [x]
  | Predicate (x, trms) -> Set.of_list (module String) (Pred.Term.fv_list trms)
  | Exists (x, f)
    | Forall (x, f) -> Set.filter (fv f) ~f:(fun y -> not (String.equal x y))
  | Neg f
    | Prev (_, f)
    | Once (_, f)
    | Historically (_, f)
    | Eventually (_, f)
    | Always (_, f)
    | Next (_, f) -> fv f
  | And (f1, f2)
    | Or (f1, f2)
    | Imp (f1, f2)
    | Iff (f1, f2)
    | Since (_, f1, f2)
    | Until (_, f1, f2) -> Set.union (fv f1) (fv f2)

let check_bindings f =
  let fv_f = fv f in
  let rec check_bindings_rec bound_vars = function
    | TT | FF -> (bound_vars, true)
    | EqConst (x, c) -> (bound_vars, true)
    | Predicate _ -> (bound_vars, true)
    | Exists (x, f)
      | Forall (x, f) -> ((Set.add bound_vars x), (not (Set.mem fv_f x)) && (not (Set.mem bound_vars x)))
    | Neg f
      | Prev (_, f)
      | Once (_, f)
      | Historically (_, f)
      | Eventually (_, f)
      | Always (_, f)
      | Next (_, f) -> check_bindings_rec bound_vars f
    | And (f1, f2)
      | Or (f1, f2)
      | Imp (f1, f2)
      | Iff (f1, f2)
      | Since (_, f1, f2)
      | Until (_, f1, f2) -> let (bound_vars1, b1) = check_bindings_rec bound_vars f1 in
                             let (bound_vars2, b2) = check_bindings_rec (Set.union bound_vars1 bound_vars) f2 in
                             (bound_vars2, b1 && b2) in
  snd (check_bindings_rec (Set.empty (module String)) f)

(* Past height *)
let rec hp = function
  | TT
    | FF
    | EqConst _
    | Predicate _ -> 0
  | Neg f
    | Exists (_, f)
    | Forall (_, f) -> hp f
  | And (f1, f2)
    | Or (f1, f2)
    | Imp (f1, f2)
    | Iff (f1, f2) -> max (hp f1) (hp f2)
  | Prev (_, f)
    | Once (_, f)
    | Historically (_, f) -> hp f + 1
  | Eventually (_, f)
    | Always (_, f)
    | Next (_, f) -> hp f
  | Since (_, f1, f2) -> max (hp f1) (hp f2) + 1
  | Until (_, f1, f2) -> max (hp f1) (hp f2)

(* Future height *)
let rec hf = function
  | TT
    | FF
    | EqConst _
    | Predicate _ -> 0
  | Neg f
    | Exists (_, f)
    | Forall (_, f) -> hf f
  | And (f1, f2)
    | Or (f1, f2)
    | Imp (f1, f2)
    | Iff (f1, f2) -> max (hf f1) (hf f2)
  | Prev (_, f)
    | Once (_, f)
    | Historically (_, f) -> hf f
  | Eventually (_, f)
    | Always (_, f)
    | Next (_, f) -> hf f + 1
  | Since (_, f1, f2) -> max (hf f1) (hf f2)
  | Until (_, f1, f2) -> max (hf f1) (hf f2) + 1

let height f = hp f + hf f

let immediate_subfs = function
  | TT
    | FF
    | EqConst _
    | Predicate _ -> []
  | Neg f
    | Exists (_, f)
    | Forall (_, f)
    | Prev (_, f)
    | Next (_, f)
    | Once (_, f)
    | Eventually (_, f)
    | Historically (_, f)
    | Always (_, f) -> [f]
  | And (f, g)
    | Or (f, g)
    | Imp (f, g)
    | Iff (f, g) -> [f; g]
  | Since (i, f, g)
    | Until (i, f, g) -> [f; g]

let rec subfs_bfs xs =
  xs @ (List.concat (List.map xs ~f:(fun x -> subfs_bfs (immediate_subfs x))))

let rec subfs_dfs h = match h with
  | TT | FF | EqConst _ | Predicate _ -> [h]
  | Neg f -> [h] @ (subfs_dfs f)
  | And (f, g) -> [h] @ (subfs_dfs f) @ (subfs_dfs g)
  | Or (f, g) -> [h] @ (subfs_dfs f) @ (subfs_dfs g)
  | Imp (f, g) -> [h] @ (subfs_dfs f) @ (subfs_dfs g)
  | Iff (f, g) -> [h] @ (subfs_dfs f) @ (subfs_dfs g)
  | Exists (_, f) -> [h] @ (subfs_dfs f)
  | Forall (_, f) -> [h] @ (subfs_dfs f)
  | Prev (_, f) -> [h] @ (subfs_dfs f)
  | Next (_, f) -> [h] @ (subfs_dfs f)
  | Once (_, f) -> [h] @ (subfs_dfs f)
  | Eventually (_, f) -> [h] @ (subfs_dfs f)
  | Historically (_, f) -> [h] @ (subfs_dfs f)
  | Always (_, f) -> [h] @ (subfs_dfs f)
  | Since (_, f, g) -> [h] @ (subfs_dfs f) @ (subfs_dfs g)
  | Until (_, f, g) -> [h] @ (subfs_dfs f) @ (subfs_dfs g)

let subfs_scope h i =
  let rec subfs_scope_rec h i =
    match h with
    | TT | FF | EqConst _ | Predicate _ -> (i, [(i, ([], []))])
    | Neg f
      | Exists (_, f)
      | Forall (_, f)
      | Prev (_, f)
      | Next (_, f)
      | Once (_, f)
      | Eventually (_, f)
      | Historically (_, f)
      | Always (_, f) -> let (i', subfs_f) = subfs_scope_rec f (i+1) in
                         (i', [(i, (List.map subfs_f ~f:fst, []))] @ subfs_f)
    | And (f, g)
      | Or (f, g)
      | Imp (f, g)
      | Iff (f, g)
      | Since (_, f, g)
      | Until (_, f, g) ->  let (i', subfs_f) = subfs_scope_rec f (i+1) in
                            let (i'', subfs_g) = subfs_scope_rec g (i'+1) in
                            (i'', [(i, ((List.map subfs_f ~f:fst), (List.map subfs_g ~f:fst)))]
                                  @ subfs_f @ subfs_g) in
  snd (subfs_scope_rec h i)

let rec preds = function
  | TT | FF | EqConst _ -> []
  | Predicate (r, trms) -> [Predicate (r, trms)]
  | Neg f | Exists (_, f) | Forall (_, f)
    | Next (_, f) | Prev (_, f)
    | Once (_, f) | Historically (_, f)
    | Eventually (_, f) | Always (_, f) -> preds f
  | And (f1, f2) | Or (f1, f2)
    | Imp (f1, f2) | Iff (f1, f2)
    | Until (_, f1, f2) | Since (_, f1, f2) -> let a1s = List.fold_left (preds f1) ~init:[]
                                                           ~f:(fun acc a -> if List.mem acc a ~equal:equal then acc
                                                                            else acc @ [a])  in
                                               let a2s = List.fold_left (preds f2) ~init:[]
                                                           ~f:(fun acc a ->
                                                             if (List.mem acc a ~equal:equal) || (List.mem a1s a ~equal:equal) then acc
                                                             else acc @ [a]) in
                                               List.append a1s a2s

let pred_names f =
  let rec pred_names_rec s = function
    | TT | FF | EqConst _ -> s
    | Predicate (r, trms) -> Set.add s r
    | Neg f | Exists (_, f) | Forall (_, f)
      | Prev (_, f) | Next (_, f)
      | Once (_, f) | Eventually (_, f)
      | Historically (_, f) | Always (_, f) -> pred_names_rec s f
    | And (f1, f2) | Or (f1, f2)
      | Imp (f1, f2) | Iff (f1, f2)
      | Until (_, f1, f2) | Since (_, f1, f2) -> Set.union (pred_names_rec s f1) (pred_names_rec s f2) in
  pred_names_rec (Set.empty (module String)) f

let op_to_string = function
  | TT -> Printf.sprintf "⊤"
  | FF -> Printf.sprintf "⊥"
  | EqConst (x, c) -> Printf.sprintf "="
  | Predicate (r, trms) -> Printf.sprintf "%s(%s)" r (Term.list_to_string trms)
  | Neg _ -> Printf.sprintf "¬"
  | And (_, _) -> Printf.sprintf "∧"
  | Or (_, _) -> Printf.sprintf "∨"
  | Imp (_, _) -> Printf.sprintf "→"
  | Iff (_, _) -> Printf.sprintf "↔"
  | Exists (x, _) -> Printf.sprintf "∃ %s." x
  | Forall (x, _) -> Printf.sprintf "∀ %s." x
  | Prev (i, _) -> Printf.sprintf "●%s" (Interval.to_string i)
  | Next (i, _) -> Printf.sprintf "○%s" (Interval.to_string i)
  | Once (i, f) -> Printf.sprintf "⧫%s" (Interval.to_string i)
  | Eventually (i, f) -> Printf.sprintf "◊%s" (Interval.to_string i)
  | Historically (i, f) -> Printf.sprintf "■%s" (Interval.to_string i)
  | Always (i, f) -> Printf.sprintf "□%s" (Interval.to_string i)
  | Since (i, _, _) -> Printf.sprintf "S%s" (Interval.to_string i)
  | Until (i, _, _) -> Printf.sprintf "U%s" (Interval.to_string i)

let rec to_string_rec l = function
  | TT -> Printf.sprintf "⊤"
  | FF -> Printf.sprintf "⊥"
  | EqConst (x, c) -> Printf.sprintf "%s = %s" x (Dom.to_string c)
  | Predicate (r, trms) -> Printf.sprintf "%s(%s)" r (Term.list_to_string trms)
  | Neg f -> Printf.sprintf "¬%a" (fun x -> to_string_rec 5) f
  | And (f, g) -> Printf.sprintf (Etc.paren l 4 "%a ∧ %a") (fun x -> to_string_rec 4) f (fun x -> to_string_rec 4) g
  | Or (f, g) -> Printf.sprintf (Etc.paren l 3 "%a ∨ %a") (fun x -> to_string_rec 3) f (fun x -> to_string_rec 4) g
  | Imp (f, g) -> Printf.sprintf (Etc.paren l 5 "%a → %a") (fun x -> to_string_rec 5) f (fun x -> to_string_rec 5) g
  | Iff (f, g) -> Printf.sprintf (Etc.paren l 5 "%a ↔ %a") (fun x -> to_string_rec 5) f (fun x -> to_string_rec 5) g
  | Exists (x, f) -> Printf.sprintf (Etc.paren l 5 "∃%s. %a") x (fun x -> to_string_rec 5) f
  | Forall (x, f) -> Printf.sprintf (Etc.paren l 5 "∀%s. %a") x (fun x -> to_string_rec 5) f
  | Prev (i, f) -> Printf.sprintf (Etc.paren l 5 "●%a %a") (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) f
  | Next (i, f) -> Printf.sprintf (Etc.paren l 5 "○%a %a") (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) f
  | Once (i, f) -> Printf.sprintf (Etc.paren l 5 "⧫%a %a") (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) f
  | Eventually (i, f) -> Printf.sprintf (Etc.paren l 5 "◊%a %a") (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) f
  | Historically (i, f) -> Printf.sprintf (Etc.paren l 5 "■%a %a") (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) f
  | Always (i, f) -> Printf.sprintf (Etc.paren l 5 "□%a %a") (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) f
  | Since (i, f, g) -> Printf.sprintf (Etc.paren l 0 "%a S%a %a") (fun x -> to_string_rec 5) f
                         (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) g
  | Until (i, f, g) -> Printf.sprintf (Etc.paren l 0 "%a U%a %a") (fun x -> to_string_rec 5) f
                         (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) g
let to_string = to_string_rec 0

let rec to_json_rec indent pos f =
  let indent' = "  " ^ indent in
  match f with
  | TT -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"TT\"\n%s}"
            indent pos indent' indent
  | FF -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"FF\"\n%s}"
            indent pos indent' indent
  | EqConst (x, c) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"EqConst\",\n%s\"variable\": \"%s\",\n%s\"constant\": \"%s\"\n%s}"
                         indent pos indent' indent' x indent' (Dom.to_string c) indent
  | Predicate (r, trms) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Predicate\",\n%s\"name\": \"%s\",\n%s\"terms\": \"%s\"\n%s}"
                             indent pos indent' indent' r indent' (Term.list_to_string trms) indent
  | Neg f -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Neg\",\n%s\n%s}"
               indent pos indent' (to_json_rec indent' "" f) indent
  | And (f, g) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"And\",\n%s,\n%s\n%s}"
                    indent pos indent' (to_json_rec indent' "l" f) (to_json_rec indent' "r" g) indent
  | Or (f, g) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Or\",\n%s,\n%s\n%s}"
                   indent pos indent' (to_json_rec indent' "l" f) (to_json_rec indent' "r" g) indent
  | Imp (f, g) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Imp\",\n%s,\n%s\n%s}"
                    indent pos indent' (to_json_rec indent' "l" f) (to_json_rec indent' "r" g) indent
  | Iff (f, g) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Iff\",\n%s,\n%s\n%s}"
                    indent pos indent' (to_json_rec indent' "l" f) (to_json_rec indent' "r" g) indent
  | Exists (x, g) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Exists\",\n%s\"variable\": \"%s\",\n%s\n%s}"
                       indent pos indent' indent' x (to_json_rec indent' "" f) indent
  | Forall (x, g) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Forall\",\n%s\"variable\": \"%s\",\n%s\n%s}"
                       indent pos indent' indent' x (to_json_rec indent' "" f) indent
  | Prev (i, f) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Prev\",\n%s\"Interval.t\": \"%s\",\n%s\n%s}"
                     indent pos indent' indent' (Interval.to_string i) (to_json_rec indent' "" f) indent
  | Next (i, f) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Next\",\n%s\"Interval.t\": \"%s\",\n%s\n%s}"
                     indent pos indent' indent' (Interval.to_string i) (to_json_rec indent' "" f) indent
  | Once (i, f) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Once\",\n%s\"Interval.t\": \"%s\",\n%s\n%s}"
                     indent pos indent' indent' (Interval.to_string i) (to_json_rec indent' "" f) indent
  | Eventually (i, f) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Eventually\",\n%s\"Interval.t\": \"%s\",\n%s\n%s}"
                           indent pos indent' indent' (Interval.to_string i) (to_json_rec indent' "" f) indent
  | Historically (i, f) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Historically\",\n%s\"Interval.t\": \"%s\",\n%s\n%s}"
                             indent pos indent' indent' (Interval.to_string i) (to_json_rec indent' "" f) indent
  | Always (i, f) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Always\",\n%s\"Interval.t\": \"%s\",\n%s\n%s}"
                       indent pos indent' indent' (Interval.to_string i) (to_json_rec indent' "" f) indent
  | Since (i, f, g) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Since\",\n%s\"Interval.t\": \"%s\",\n%s,\n%s\n%s}"
                         indent pos indent' indent' (Interval.to_string i) (to_json_rec indent' "l" f) (to_json_rec indent' "r" g) indent
  | Until (i, f, g) -> Printf.sprintf "%s\"%sformula\": {\n%s\"type\": \"Until\",\n%s\"Interval.t\": \"%s\",\n%s,\n%s\n%s}"
                         indent pos indent' indent' (Interval.to_string i) (to_json_rec indent' "l" f) (to_json_rec indent' "r" g) indent
let to_json = to_json_rec "    " ""

let rec to_latex_rec l = function
  | TT -> Printf.sprintf "\\top"
  | FF -> Printf.sprintf "\\bot"
  | EqConst (x, c) -> Printf.sprintf "%s = %s" (Etc.escape_underscores x) (Dom.to_string c)
  | Predicate (r, trms) -> Printf.sprintf "%s\\,(%s)" (Etc.escape_underscores r) (Term.list_to_string trms)
  | Neg f -> Printf.sprintf "\\neg %a" (fun x -> to_latex_rec 5) f
  | And (f, g) -> Printf.sprintf (Etc.paren l 4 "%a \\land %a") (fun x -> to_latex_rec 4) f (fun x -> to_latex_rec 4) g
  | Or (f, g) -> Printf.sprintf (Etc.paren l 3 "%a \\lor %a") (fun x -> to_latex_rec 3) f (fun x -> to_latex_rec 4) g
  | Imp (f, g) -> Printf.sprintf (Etc.paren l 5 "%a \\rightarrow %a") (fun x -> to_latex_rec 5) f (fun x -> to_latex_rec 5) g
  | Iff (f, g) -> Printf.sprintf (Etc.paren l 5 "%a \\leftrightarrow %a") (fun x -> to_latex_rec 5) f (fun x -> to_latex_rec 5) g
  | Exists (x, f) -> Printf.sprintf (Etc.paren l 5 "\\exists %s. %a") x (fun x -> to_latex_rec 5) f
  | Forall (x, f) -> Printf.sprintf (Etc.paren l 5 "\\forall %s. %a") x (fun x -> to_latex_rec 5) f
  | Prev (i, f) -> Printf.sprintf (Etc.paren l 5 "\\Prev{%a} %a") (fun x -> Interval.to_latex) i (fun x -> to_latex_rec 5) f
  | Next (i, f) -> Printf.sprintf (Etc.paren l 5 "\\Next{%a} %a") (fun x -> Interval.to_latex) i (fun x -> to_latex_rec 5) f
  | Once (i, f) -> Printf.sprintf (Etc.paren l 5 "\\Once{%a} %a") (fun x -> Interval.to_latex) i (fun x -> to_latex_rec 5) f
  | Eventually (i, f) -> Printf.sprintf (Etc.paren l 5 "\\Eventually{%a} %a") (fun x -> Interval.to_latex) i (fun x -> to_latex_rec 5) f
  | Historically (i, f) -> Printf.sprintf (Etc.paren l 5 "\\Historically{%a} %a") (fun x -> Interval.to_latex) i (fun x -> to_latex_rec 5) f
  | Always (i, f) -> Printf.sprintf (Etc.paren l 5 "\\Always{%a} %a") (fun x -> Interval.to_latex) i (fun x -> to_latex_rec 5) f
  | Since (i, f, g) -> Printf.sprintf (Etc.paren l 0 "%a \\Since{%a} %a") (fun x -> to_latex_rec 5) f
                         (fun x -> Interval.to_latex) i (fun x -> to_latex_rec 5) g
  | Until (i, f, g) -> Printf.sprintf (Etc.paren l 0 "%a \\Until{%a} %a") (fun x -> to_latex_rec 5) f
                         (fun x -> Interval.to_latex) i (fun x -> to_latex_rec 5) g
let to_latex = to_latex_rec 0
