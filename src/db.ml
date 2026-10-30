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

module Event = struct

  module T = struct

    type t = string * Dom.t list * bool [@@deriving compare, sexp_of]

    let to_string (name, ds, b) = Printf.sprintf "%s(%s)" name (Dom.list_to_string ds)

    let to_json (name, ds, b) =
      String.concat ~sep:", "
        (List.map2_exn (Pred.Sig.vars name) ds  ~f:(fun x d ->
             Printf.sprintf "{ " ^
               Printf.sprintf "\"var\": \"%s\", " x ^
                 Printf.sprintf "\"value\": \"%s\" " (Dom.to_string d) ^
                   Printf.sprintf "}"))

  end

  include T
  include Comparable.Make(T)

end

type t = (Event.t, Event.comparator_witness) Set.t

let create evtl = Set.of_list (module Event) evtl

let event name consts s =
  let pred_sig = Hashtbl.find_exn Pred.Sig.table name in
  if pred_sig.arity = List.length consts then
    let dom_list = 
      List.map2_exn pred_sig.ntconsts consts
             ~f:(fun tc c -> match snd tc with
                             | TInt -> Dom.Int (Int.of_string c)
                             | TStr -> Str c
                             | TFloat -> Float (Float.of_string c))
    in
    (name, dom_list, s) 
  else raise (Invalid_argument (Printf.sprintf "predicate %s has arity %d" name pred_sig.arity))

let add_event db evt = Set.add db evt

(*
let to_string db =
  Set.fold db ~init:"" ~f:(fun acc evt -> acc ^ Event.to_string evt ^ "\n")
*)
let to_string db =
  Set.fold db ~init:"" ~f:(fun acc evt -> Event.to_string evt ^ "\n")

let to_json db =
  "[ " ^ (String.concat ~sep:", "
            (List.rev(Set.fold db ~init:[] ~f:(fun acc evt -> 
              Event.to_json evt :: acc)))) ^ "] "
