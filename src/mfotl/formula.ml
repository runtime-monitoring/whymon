(*******************************************************************)
(*     This is part of Explanator2, it is distributed under the    *)
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
let predicate p_name strms = Predicate (p_name, make_terms p_name strms)
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
  | TT, TT
    | FF, FF -> true
  | Predicate (r, trms), Predicate (r', trms') -> String.equal r r' && List.equal Term.equal trms trms'
  | Neg f, Neg f' -> f == f'
  | And (f, g), And (f', g')
    | Or (f, g), Or (f', g')
    | Imp (f, g), Imp (f', g')
    | Iff (f, g), Iff (f', g') -> f == f' && g == g'
  | Exists (x, f), Exists (x', f')
    | Forall (x, f), Forall (x', f') -> x == x' && f == f'
  | Prev (i, f), Prev (i', f')
    | Next (i, f), Next (i', f')
    | Once (i, f), Once (i', f')
    | Eventually (i, f), Eventually (i', f')
    | Historically (i, f), Historically (i', f')
    | Always (i, f), Always (i', f') -> i == i' && f == f'
  | Since (i, f, g), Since (i', f', g')
    | Until (i, f, g), Until (i', f', g') -> i == i' && f == f' && g == g'
  | _ -> false

(* Past height *)
let rec hp x = match x with
  | TT
    | FF
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
let rec hf x = match x with
  | TT
    | FF
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

let immediate_subfs x =
  match x with
  | TT
    | FF
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
  xs @ (List.concat (List.map xs (fun x -> subfs_bfs (immediate_subfs x))))

let rec subfs_dfs x = match x with
  | TT -> [tt]
  | FF -> [ff]
  | Predicate (r, trms) -> [Predicate (r, trms)]
  | Neg f -> [neg f] @ (subfs_dfs f)
  | And (f, g) -> [conj f g] @ (subfs_dfs f) @ (subfs_dfs g)
  | Or (f, g) -> [disj f g] @ (subfs_dfs f) @ (subfs_dfs g)
  | Imp (f, g) -> [imp f g] @ (subfs_dfs f) @ (subfs_dfs g)
  | Iff (f, g) -> [iff f g] @ (subfs_dfs f) @ (subfs_dfs g)
  | Exists (x, f) -> [exists x f] @ (subfs_dfs f)
  | Forall (x, f) -> [forall x f] @ (subfs_dfs f)
  | Prev (i, f) -> [prev i f] @ (subfs_dfs f)
  | Next (i, f) -> [next i f] @ (subfs_dfs f)
  | Once (i, f) -> [once i f] @ (subfs_dfs f)
  | Eventually (i, f) -> [eventually i f] @ (subfs_dfs f)
  | Historically (i, f) -> [historically i f] @ (subfs_dfs f)
  | Always (i, f) -> [always i f] @ (subfs_dfs f)
  | Since (i, f, g) -> [since i f g] @ (subfs_dfs f) @ (subfs_dfs g)
  | Until (i, f, g) -> [until i f g] @ (subfs_dfs f) @ (subfs_dfs g)

let rec preds = function
  | TT | FF -> []
  | Predicate (r, trms) -> [Predicate (r, trms)]
  | Neg f | Next (_, f) | Prev (_, f)
    | Once (_, f) | Historically (_, f)
    | Eventually (_, f) | Always (_, f) -> preds f
  | And (f1, f2) | Or (f1, f2)
    | Imp (f1, f2) | Iff (f1, f2)
    | Until (_, f1, f2) | Since (_, f1, f2) -> let a1s = List.fold_left (preds f1) ~init:[]
                                                           ~f:(fun acc a -> if List.mem acc a equal then acc
                                                                            else acc @ [a])  in
                                               let a2s = List.fold_left (preds f2) ~init:[]
                                                           ~f:(fun acc a ->
                                                             if (List.mem acc a equal) || (List.mem a1s a equal) then acc
                                                             else acc @ [a]) in
                                               List.append a1s a2s

let op_to_string = function
  | TT -> Printf.sprintf "⊤"
  | FF -> Printf.sprintf "⊥"
  | Predicate (r, trms) -> Printf.sprintf "%s(%s)" r (Term.list_to_string trms)
  | Neg _ -> Printf.sprintf "¬"
  | And (_, _) -> Printf.sprintf "∧"
  | Or (_, _) -> Printf.sprintf "∨"
  | Imp (_, _) -> Printf.sprintf "→"
  | Iff (_, _) -> Printf.sprintf "↔"
  | Exists (_, _) -> Printf.sprintf "∃"
  | Forall (_, _) -> Printf.sprintf "∀"
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
  | _ -> ""
let to_json = to_json_rec "    " ""