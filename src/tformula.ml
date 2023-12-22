open Base
open Pred

open Formula

type core_t =
  | TTT
  | TFF
  | TEqConst of string * Dom.t
  | TPredicate of string * Term.t list
  | TNeg of t
  | TAnd of Side.t * t * t
  | TOr of Side.t * t * t
  | TImp of Side.t * t * t
  | TIff of Side.t * Side.t * t * t
  | TExists of string * Dom.tt * t
  | TForall of string * Dom.tt * t
  | TPrev of Interval.t * t
  | TNext of Interval.t * t
  | TOnce of Interval.t * t
  | TEventually of Interval.t * t
  | THistorically of Interval.t * t
  | TAlways of Interval.t * t
  | TSince of Side.t * Interval.t * t * t
  | TUntil of Side.t * Interval.t * t * t

and t = { f: core_t; enftype: EnfType.t }

let rec core_of_formula = function
  | TT -> TTT
  | FF -> TFF
  | EqConst (x, v) -> TEqConst (x, v)
  | Predicate (e, t) -> TPredicate (e, t)
  | Neg f -> TNeg (of_formula f)
  | And (s, f, g) -> TAnd (s, of_formula f, of_formula g)
  | Or (s, f, g) -> TOr (s, of_formula f, of_formula g)
  | Imp (s, f, g) -> TImp (s, of_formula f, of_formula g)
  | Iff (s, t, f, g) -> TIff (s, t, of_formula f, of_formula g)
  | Exists (x, tt, f) -> TExists (x, tt, of_formula f)
  | Forall (x, tt, f) -> TForall (x, tt, of_formula f)
  | Prev (i, f) -> TPrev (i, of_formula f)
  | Next (i, f) -> TNext (i, of_formula f)
  | Once (i, f) -> TOnce (i, of_formula f)
  | Eventually (i, f) -> TEventually (i, of_formula f)
  | Historically (i, f) -> THistorically (i, of_formula f)
  | Always (i, f) -> TAlways (i, of_formula f)
  | Since (s, i, f, g) -> TSince (s, i, of_formula f, of_formula g)
  | Until (s, i, f, g) -> TUntil (s, i, of_formula f, of_formula g)

and of_formula f = { f = core_of_formula f; enftype = EnfType.Obs }

let ttrue  = { f = TTT; enftype = Cau }
let tfalse = { f = TFF; enftype = Sup }

let neg f enftype = { f = TNeg f; enftype }
let conj side f g enftype = { f = TAnd (side, f, g); enftype }

let rec apply_valuation_core v =
  let r = apply_valuation v in
  let apply_valuation_term v = function
    | Term.Var x when Map.mem v x -> Term.Const (Map.find_exn v x)
    | Var x -> Var x
    | Const d -> Const d in
  function
  | TTT -> TTT
  | TFF -> TFF
  | TEqConst (x, d) when Map.find v x == Some d -> TTT
  | TEqConst (x, d) when Map.mem v x -> TFF
  | TEqConst (x, d) -> TEqConst (x, d)
  | TPredicate (e, t) -> TPredicate (e, List.map t (apply_valuation_term v))
  | TNeg f -> TNeg (r f)
  | TAnd (s, f, g) -> TAnd (s, r f, r g)
  | TOr (s, f, g) -> TOr (s, r f, r g)
  | TImp (s, f, g) -> TImp (s, r f, r g)
  | TIff (s, t, f, g) -> TIff (s, t, r f, r g)
  | TExists (x, tt, f) -> TExists (x, tt, r f)
  | TForall (x, tt, f) -> TForall (x, tt, r f)
  | TPrev (i, f) -> TPrev (i, r f)
  | TNext (i, f) -> TNext (i, r f)
  | TOnce (i, f) -> TOnce (i, r f)
  | TEventually (i, f) -> TEventually (i, r f)
  | THistorically (i, f) -> THistorically (i, r f)
  | TAlways (i, f) -> TAlways (i, r f)
  | TSince (s, i, f, g) -> TSince (s, i, r f, r g)
  | TUntil (s, i, f, g) -> TUntil (s, i, r f, r g)
and apply_valuation v f = { f with f = apply_valuation_core v f.f }

let rec rank_core = function
  | TTT | TFF -> 0
  | TEqConst _ -> 0
  | TPredicate (r, _) -> Pred.Sig.rank r
  | TNeg f
    | TExists (_, _, f)
    | TForall (_, _, f)
    | TPrev (_, f)
    | TNext (_, f)
    | TOnce (_, f)
    | TEventually (_, f)
    | THistorically (_, f)
    | TAlways (_, f) -> rank f
  | TAnd (_, f, g)
    | TOr (_, f, g)
    | TImp (_, f, g)
    | TIff (_, _, f, g)
    | TSince (_, _, f, g)
    | TUntil (_, _, f, g) -> rank f + rank g
and rank f = rank_core f.f

let rec op_to_string_core = function
  | TTT -> Printf.sprintf "⊤"
  | TFF -> Printf.sprintf "⊥"
  | TEqConst (x, c) -> Printf.sprintf "="
  | TPredicate (r, trms) -> Printf.sprintf "%s(%s)" r (Term.list_to_string trms)
  | TNeg _ -> Printf.sprintf "¬"
  | TAnd (_, _, _) -> Printf.sprintf "∧"
  | TOr (_, _, _) -> Printf.sprintf "∨"
  | TImp (_, _, _) -> Printf.sprintf "→"
  | TIff (_, _, _, _) -> Printf.sprintf "↔"
  | TExists (x, _, _) -> Printf.sprintf "∃ %s." x
  | TForall (x, _, _) -> Printf.sprintf "∀ %s." x
  | TPrev (i, _) -> Printf.sprintf "●%s" (Interval.to_string i)
  | TNext (i, _) -> Printf.sprintf "○%s" (Interval.to_string i)
  | TOnce (i, f) -> Printf.sprintf "⧫%s" (Interval.to_string i)
  | TEventually (i, f) -> Printf.sprintf "◊%s" (Interval.to_string i)
  | THistorically (i, f) -> Printf.sprintf "■%s" (Interval.to_string i)
  | TAlways (i, f) -> Printf.sprintf "□%s" (Interval.to_string i)
  | TSince (_, i, _, _) -> Printf.sprintf "S%s" (Interval.to_string i)
  | TUntil (_, i, _, _) -> Printf.sprintf "U%s" (Interval.to_string i)
and op_to_string f = op_to_string_core f.f


let rec to_string_core_rec l = function
  | TTT -> Printf.sprintf "⊤"
  | TFF -> Printf.sprintf "⊥"
  | TEqConst (x, c) -> Printf.sprintf "%s = %s" x (Dom.to_string c)
  | TPredicate (r, trms) -> Printf.sprintf "%s(%s)" r (Term.list_to_string trms)
  | TNeg f -> Printf.sprintf "¬%a" (fun x -> to_string_rec 5) f
  | TAnd (s, f, g) -> Printf.sprintf (Etc.paren l 4 "%a ∧%a %a") (fun x -> to_string_rec 4) f (fun x -> Side.to_string) s (fun x -> to_string_rec 4) g
  | TOr (s, f, g) -> Printf.sprintf (Etc.paren l 3 "%a ∨%a %a") (fun x -> to_string_rec 3) f (fun x -> Side.to_string) s (fun x -> to_string_rec 4) g
  | TImp (s, f, g) -> Printf.sprintf (Etc.paren l 5 "%a →%a %a") (fun x -> to_string_rec 5) f (fun x -> Side.to_string) s (fun x -> to_string_rec 5) g
  | TIff (s, t, f, g) -> Printf.sprintf (Etc.paren l 5 "%a ↔%a %a") (fun x -> to_string_rec 5) f (fun x -> Side.to_string2) (s, t) (fun x -> to_string_rec 5) g
  | TExists (x, _, f) -> Printf.sprintf (Etc.paren l 5 "∃%s. %a") x (fun x -> to_string_rec 5) f
  | TForall (x, _, f) -> Printf.sprintf (Etc.paren l 5 "∀%s. %a") x (fun x -> to_string_rec 5) f
  | TPrev (i, f) -> Printf.sprintf (Etc.paren l 5 "●%a %a") (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) f
  | TNext (i, f) -> Printf.sprintf (Etc.paren l 5 "○%a %a") (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) f
  | TOnce (i, f) -> Printf.sprintf (Etc.paren l 5 "⧫%a %a") (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) f
  | TEventually (i, f) -> Printf.sprintf (Etc.paren l 5 "◊%a %a") (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) f
  | THistorically (i, f) -> Printf.sprintf (Etc.paren l 5 "■%a %a") (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) f
  | TAlways (i, f) -> Printf.sprintf (Etc.paren l 5 "□%a %a") (fun x -> Interval.to_string) i (fun x -> to_string_rec 5) f
  | TSince (s, i, f, g) -> Printf.sprintf (Etc.paren l 0 "%a S%a%a %a") (fun x -> to_string_rec 5) f
                         (fun x -> Interval.to_string) i (fun x -> Side.to_string) s (fun x -> to_string_rec 5) g
  | TUntil (s, i, f, g) -> Printf.sprintf (Etc.paren l 0 "%a U%a%a %a") (fun x -> to_string_rec 5) f
                             (fun x -> Interval.to_string) i (fun x -> Side.to_string) s (fun x -> to_string_rec 5) g
and to_string_rec l form =
  if form.enftype == EnfType.Obs then
    Printf.sprintf "%a" (fun x -> to_string_core_rec 5) form.f
  else
    Printf.sprintf (Etc.paren l 0 "%a : %s") (fun x -> to_string_core_rec 5) form.f (EnfType.to_string form.enftype)

let to_string = to_string_rec 0
