import gleam/io
import eyg/ast
import eyg/ast/pattern
import eyg/typer.{infer, init, resolve}
import eyg/typer/monotype
import eyg/typer/polytype

pub fn assignment_test() {
  let typer = init([])
  let untyped =
    ast.Let(pattern.Variable("foo"), ast.Tuple([]), ast.Variable("foo"))
  let Ok(#(type_, _typer)) = infer(untyped, typer)
  assert monotype.Tuple([]) = type_
}

pub fn tuple_pattern_test() {
  let typer = init([])
  let untyped =
    ast.Let(
      pattern.Tuple(["a"]),
      ast.Tuple([ast.Binary("")]),
      ast.Variable("a"),
    )
  let Ok(#(type_, typer)) = infer(untyped, typer)
  //   could always resolve within infer fn
  assert monotype.Binary = resolve(type_, typer)
}

pub fn incorrect_tuple_size_test() {
  let typer = init([])
  let untyped = ast.Let(pattern.Tuple(["a"]), ast.Tuple([]), ast.Variable("a"))
  let Error(typer.IncorrectArity(1, 0)) = infer(untyped, typer)
}

pub fn not_a_tuple_test() {
  let typer = init([])
  let untyped = ast.Let(pattern.Tuple(["a"]), ast.Binary(""), ast.Variable("a"))
  let Error(typer.UnmatchedTypes(monotype.Tuple([_]), monotype.Binary)) =
    infer(untyped, typer)
}

pub fn matching_row_test() {
  let typer = init([])
  let untyped =
    ast.Let(
      pattern.Row([#("foo", "a")]),
      ast.Row([#("foo", ast.Binary(""))]),
      ast.Variable("a"),
    )
  let Ok(#(type_, typer)) = infer(untyped, typer)
  assert monotype.Binary = resolve(type_, typer)
}

pub fn growing_row_pattern_test() {
  let typer = init([#("x", polytype.Polytype([], monotype.Unbound(-1)))])
  let untyped =
    ast.Let(
      pattern.Row([#("foo", "a")]),
      ast.Variable("x"),
      ast.Let(
        pattern.Row([#("bar", "b")]),
        ast.Variable("x"),
        ast.Tuple([ast.Variable("a"), ast.Variable("b")]),
      ),
    )
  let Ok(#(type_, typer)) = infer(untyped, typer)

  assert monotype.Tuple([monotype.Unbound(i), monotype.Unbound(j)]) =
    resolve(type_, typer)
  assert True = i != j
  assert monotype.Row([a, b], _) = resolve(monotype.Unbound(-1), typer)
  assert #("foo", _) = a
  assert #("bar", _) = b
}

pub fn matched_row_test() {
  let typer = init([#("x", polytype.Polytype([], monotype.Unbound(-1)))])
  let untyped =
    ast.Let(
      pattern.Row([#("foo", "a")]),
      ast.Variable("x"),
      ast.Let(
        pattern.Row([#("foo", "b")]),
        ast.Variable("x"),
        ast.Tuple([ast.Variable("a"), ast.Variable("b")]),
      ),
    )
  let Ok(#(type_, typer)) = infer(untyped, typer)

  assert monotype.Tuple([monotype.Unbound(i), monotype.Unbound(j)]) =
    resolve(type_, typer)
  // Tests that the row fields are being resolve
  assert True = i == j
  assert monotype.Row([a], _) = resolve(monotype.Unbound(-1), typer)
  assert #("foo", _) = a
}

pub fn missing_row_test() {
  let typer = init([])
  let untyped =
    ast.Let(pattern.Row([#("foo", "a")]), ast.Row([]), ast.Variable("a"))
  let Error(typer.MissingFields(extra)) = infer(untyped, typer)
  let [#("foo", _)] = extra
}
// Have resolved as a type wrapper