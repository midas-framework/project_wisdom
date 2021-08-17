import gleam/io
import eyg/ast
import eyg/ast/pattern
import eyg/typer.{infer, init}
import eyg/typer/monotype
import eyg/typer/polytype.{State}

pub fn infer_variant_test() {
  let typer = init([])
  let untyped =
    ast.Name(
      #(
        "Boolean",
        #([], [#("True", monotype.Tuple([])), #("False", monotype.Tuple([]))]),
      ),
      ast.Call(ast.Constructor("Boolean", "True"), ast.Tuple([])),
    )
  let Ok(#(type_, typer)) = infer(untyped, typer)
  let State(substitutions: substitutions, ..) = typer

  assert monotype.Nominal("Boolean", []) =
    monotype.resolve(type_, substitutions)
}

pub fn infer_concrete_parameterised_variant_test() {
  let typer = init([])
  let untyped =
    ast.Name(
      #(
        "Option",
        #([1], [#("Some", monotype.Unbound(1)), #("None", monotype.Tuple([]))]),
      ),
      ast.Call(ast.Constructor("Option", "Some"), ast.Binary("value")),
    )
  let Ok(#(type_, typer)) = infer(untyped, typer)
  let State(substitutions: substitutions, ..) = typer
  assert monotype.Nominal("Option", [monotype.Binary]) =
    monotype.resolve(type_, substitutions)
}

pub fn infer_unspecified_parameterised_variant_test() {
  let typer = init([])
  let untyped =
    ast.Name(
      #(
        "Option",
        #([1], [#("Some", monotype.Unbound(1)), #("None", monotype.Tuple([]))]),
      ),
      ast.Call(ast.Constructor("Option", "None"), ast.Tuple([])),
    )
  let Ok(#(type_, typer)) = infer(untyped, typer)
  let State(substitutions: substitutions, ..) = typer
  assert monotype.Nominal("Option", [monotype.Unbound(_)]) =
    monotype.resolve(type_, substitutions)
}

pub fn unknown_named_type_test() {
  let typer = init([])
  let untyped = ast.Call(ast.Constructor("Foo", "X"), ast.Tuple([]))
  let Error(reason) = infer(untyped, typer)
  assert typer.UnknownType("Foo") = reason
}

pub fn unknown_variant_test() {
  let typer = init([])
  let untyped =
    ast.Name(
      #(
        "Boolean",
        #([], [#("True", monotype.Tuple([])), #("False", monotype.Tuple([]))]),
      ),
      ast.Call(ast.Constructor("Boolean", "Perhaps"), ast.Tuple([])),
    )
  let Error(reason) = infer(untyped, typer)
  assert typer.UnknownVariant("Perhaps", "Boolean") = reason
}

pub fn duplicate_variant_test() {
  let typer = init([])
  let untyped =
    ast.Name(
      #(
        "Boolean",
        #([], [#("True", monotype.Tuple([])), #("False", monotype.Tuple([]))]),
      ),
      ast.Name(
        #(
          "Boolean",
          #([], [#("True", monotype.Tuple([])), #("False", monotype.Tuple([]))]),
        ),
        ast.Binary(""),
      ),
    )
  let Error(reason) = infer(untyped, typer)
  assert typer.DuplicateType("Boolean") = reason
}

pub fn mismatched_inner_type_test() {
  let typer = init([])
  let untyped =
    ast.Name(
      #(
        "Boolean",
        #([], [#("True", monotype.Tuple([])), #("False", monotype.Tuple([]))]),
      ),
      ast.Call(ast.Constructor("Boolean", "True"), ast.Binary("")),
    )
  let Error(reason) = infer(untyped, typer)
  assert reason = typer.UnmatchedTypes(monotype.Tuple([]), monotype.Binary)
}
// TODO pattern destructure OR case
// sum types don't need to be nominal, Homever there are very helpful to label the alternatives and some degree of nominal typing is useful for global look up
// pub fn true(x) {
//   fn(a, b) {a(x)}
// }
// pub fn false(x) {
//   fn(a, b) {b(x)}
// }
// fn main() { 
//   let bool = case 1 {
//     1 -> true([])
//     2 -> false([])
//   }
//   let r = bool(fn (_) {"hello"}, fn (_) {"world"})
// }
