(*******************************************************************)
(*     This is part of Explanator2, it is distributed under the    *)
(*     terms of the GNU Lesser General Public License version 3    *)
(*           (see file LICENSE for more details)                   *)
(*                                                                 *)
(*  Copyright 2021:                                                *)
(*  Dmitriy Traytel (UCPH)                                         *)
(*  Leonardo Lima (UCPH)                                           *)
(*******************************************************************)

open Lib.Util
open Lib.Expl
open Lib.Mtl
open Lib.Io
open Lib.Mtl_parser
open Lib.Mtl_lexer
open Lib.Monitor

module Main = struct

  exception EXIT

  let full_ref = ref true
  let check_ref = ref false
  let debug_ref = ref false
  let json_ref = ref false
  let mode_ref = ref ALL
  let out_mode_ref = ref PLAIN
  let measure_le_ref = ref None
  let fmla_ref = ref None
  let log_ref = ref stdin
  let out_ref = ref stdout
  let last_tp = ref 0

  let usage () =
    Format.eprintf
      "Example usage: explanator2 -O size -mode sat -fmla test.fmla -log test.log -out test.out
       Arguments:
       \t -ap      - output only the \"responsible atomic proposition\" view
       \t -check   - include output of verified checker
       \t -mode
       \t\t all    - output all satisfaction and violation proofs (default)
       \t\t sat    - output only satisfaction proofs
       \t\t viol   - output only violation proofs
       \t -out_mode
       \t\t plain  - plain output (default)
       \t\t json   - JSON output
       \t\t debug  - plain verbose output (useful for debugging)
       \t -O (measure)
       \t\t size   - optimize proof size (default)
       \t\t high   - optimize highest time-point occuring in a proof (lower is better)
       \t\t pred   - optimize multiset cardinality of atomic predicates
       \t\t none   - give any proof
       \t -fmla
       \t\t <file> or <string> - formula to be explained
       \t -log
       \t\t <file> - log file (default: stdin)
       \t -out
       \t\t <file> - output file where the explanation is printed to (default: stdout)\n%!";
    raise EXIT

  let mode_error () =
    Format.eprintf "mode should be either \"sat\", \"viol\" or \"all\" (without quotes)\n%!";
    raise EXIT

  let out_mode_error () =
    Format.eprintf "out_mode should be either \"plain\", \"json\" or \"debug\" (without quotes)\n%!";
    raise EXIT

  let measure_error () =
    Format.eprintf "measure should be either \"size\", \"high\", \"pred\", or \"none\" (without quotes)\n%!";
    raise EXIT

  let process_args =
    let rec go = function
      | ("-ap" :: args) ->
         full_ref := false;
         go args
      | ("-check" :: args) ->
         check_ref := true;
         go args
      | ("-out_mode" :: out_mode :: args) ->
         out_mode_ref :=
           (match out_mode with
            | "plain" | "PLAIN" | "Plain" -> PLAIN
            | "json" | "JSON" | "Json" -> JSON
            | "debug" | "DEBUG" | "Debug" -> DEBUG
            | _ -> mode_error ());
         go args
      | ("-mode" :: mode :: args) ->
         mode_ref :=
           (match mode with
            | "all" | "ALL" | "All" -> ALL
            | "sat" | "SAT" | "Sat" -> SAT
            | "viol" | "VIOL" | "Viol" -> VIOL
            | _ -> mode_error ());
         go args
      | ("-O" :: measure :: args) ->
         let measure_le =
           match measure with
           | "size" | "SIZE" | "Size" -> size_le
           | "high" | "HIGH" | "High" -> high_le
           | "pred" | "PRED" | "Pred" -> predicates_le
           | "none" | "NONE" | "None" -> (fun _ _ -> true)
           | _ -> measure_error () in
         measure_le_ref :=
           (match !measure_le_ref with
            | None -> Some measure_le
            | Some measure_le' -> Some(prod measure_le measure_le'));
         go args
      | ("-Olex" :: measure :: args) ->
         let measure_le =
           match measure with
           | "size" | "SIZE" | "Size" -> size_le
           | "high" | "HIGH" | "High" -> high_le
           | "pred" | "PRED" | "Pred" -> predicates_le
           | "none" | "NONE" | "None" -> (fun _ _ -> true)
           | _ -> measure_error () in
         measure_le_ref :=
           (match !measure_le_ref with
            | None -> Some measure_le
            | Some measure_le' -> Some(lex measure_le measure_le'));
         go args
      | ("-log" :: logfile :: args) ->
         last_tp := (count_lines logfile) - 1;
         log_ref := open_in logfile;
         go args
      | ("-fmla" :: fmlafile :: args) ->
         (try
            let in_ch = open_in fmlafile in
            fmla_ref := Some(Lib.Mtl_parser.formula Lib.Mtl_lexer.token (Lexing.from_channel in_ch));
            close_in in_ch
          with
            _ -> fmla_ref := Some(Lib.Mtl_parser.formula Lib.Mtl_lexer.token (Lexing.from_string fmlafile)));
         go args
      | ("-out" :: outfile :: args) ->
         out_ref := open_out outfile;
         go args
      | [] -> ()
      | _ -> usage () in
    go

  let _ =
    try
      process_args (List.tl (Array.to_list Sys.argv));
      match !fmla_ref with
      | None -> ()
      | Some(f) -> let measure_le =
                     match !measure_le_ref with
                     | None -> size_le
                     | Some measure_le' -> measure_le' in
                   if !full_ref then
                     let _ = monitor !log_ref !out_ref !mode_ref !out_mode_ref !check_ref measure_le f !last_tp in ()
                   else ()
    with
    | End_of_file -> let () = output_closing !out_ref !out_mode_ref in close_out !out_ref; exit 0
    | EXIT -> close_out !out_ref; exit 1

end