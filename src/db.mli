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
open Etc

module Event : sig
  type t = string * Dom.t list [@@deriving compare, sexp_of]
  include Comparable.S with type t := t
end

type t = (Event.t, Event.comparator_witness) Set.t

val create: Event.t list -> t

val event: string -> string list -> Event.t

val add_event: t -> Event.t -> t

val to_string: t -> string

val to_json: t -> string
