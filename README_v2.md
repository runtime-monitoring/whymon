# WhyMon: explanations as verdicts

**WhyMon** is a runtime monitoring tool that produces explanations as verdicts.
Metric first-order temporal logic (MFOTL).

## Getting Started

To execute the project locally, follow the instructions below.

### Prerequisites

**WhyMon** is written in OCaml and requires a recent version of the OCaml compiler
(>= 4.11). We recommend installing OCaml's package manager
[opam](https://opam.ocaml.org/doc/Install.html), which includes OCaml's compiler.

For instance, you can create an OCaml `5.1.0` switch and initialize the environment
variables of your terminal by running

```
$ opam switch create 5.1.0
$ eval $(opam config env)
```

To install **WhyMon**'s dependencies, run

```
$ opam install dune core_kernel base zarith menhir js_of_ocaml js_of_ocaml-ppx zarith_stubs_js
```

At this point, you are able to locally execute **WhyMon**'s command line
interface (CLI).

However, to locally execute **WhyMon**'s graphical user interface (GUI), you
also need [Node.js](https://nodejs.org/en/download/package-manager) and the
[Ace editor's fork](https://github.com/leonardolima/ace-mfotl) that includes
syntax highlighting for **WhyMon**'s inputs.

Specifically, run

```
$ npm install
```

from the `vis` folder to install the GUI's dependencies. Furthermore,
assuming that `whymon` and `ace-mfotl` are located in the same folder, run

```
$ npm install
$ node Makefile.dryice.js full
```

from the `ace-mfotl` folder.

### Running

From **WhyMon**'s folder (`whymon`), you can compile the code with

```
$ dune build
```

This generates the `whymon/bin/whymon.exe` executable. Moreover, running

```
$ ./bin/whymon.exe
```

from the `whymon` folder presents **WhyMon**'s CLI usage statement.

### Formalization

The file [src/checker.ml](src/checker.ml) corresponds to the code extracted from the Isabelle formalization.

You can also extract this code on your local machine.

The formalization is compatible with [Isabelle 2022](https://isabelle.in.tum.de/website-Isabelle2022/), and depends on the corresponding [Archive of Formal Proofs (AFP) version](https://foss.heptapod.net/isa-afp/afp-devel/-/tree/Isabelle2022).

After setting up the AFP locally (by following [these](https://www.isa-afp.org/help/) instructions), you can run

```
$ isabelle build -vd thys -eD code
```

from inside the [formalization](formalization/) folder to produce the file `formalization/code/checker.ocaml`.

### Syntax

### Metric First-Order Temporal Logic
```
{PRED} ::= string

{VAR} ::= string

{VARS} ::=   {VAR}
           | {VAR}, {VARS}

{CONST} ::= quoted string

{I}  ::= [{NAT}, {UPPERBOUND}]

{UPPERBOUND} ::=   {NAT}
                 | INFINITY   (∞)

{f} ::=   {PRED}({VARS})
        | true                  (⊤)
        | false                 (⊥)
        | {VAR} EQCONST {CONST} (=)
        | NOT {f}               (¬)
        | {f} AND {f}           (∧)
        | {f} OR  {f}           (∨)
        | {f} IMPLIES {f}       (→)
        | {f} IFF {f}           (↔)
        | EXISTS {VAR}. {f}     (∃)
        | FORALL {VAR}. {f}     {∀}
        | PREV{I} {f}           (●)
        | NEXT{I} {f}           (○)
        | ONCE{I} {f}           (⧫)
        | EVENTUALLY{I} {f}     (◊)
        | HISTORICALLY{I} {f}   (■)
        | ALWAYS{I} {f}         (□)
        | {f} SINCE{I} {f}      (S)
        | {f} UNTIL{I} {f}      (U)
        | {f} TRIGGER{I} {f}    (T)
        | {f} RELEASE{I} {f}    (R)
```

Note that this tool also supports the equivalent Unicode characters (on the right).

### Signature
```
{TYPE} ::= string | int

{VARTYPES} ::=   {VAR}:{TYPE}
               | {VAR}:{TYPE}, {VARTYPES}

{SIG} ::=   {PRED}({VARTYPES})
          | {PRED}({VARTYPES}) \n {SIG}
```

### Trace
```
{VALUES} ::=   string
             | string, {VALUES}

{TRACE} :=   @{NAT} {PREDICATE}(VALUES)*
           | @{NAT} {PREDICATE}()* \n {TRACE}
```

where `0 <= {NAT} <= 2147483647`.

## License

This project is licensed under the GNU Lesser GPL-3.0 license - see [LICENSE](LICENSE) for details.
