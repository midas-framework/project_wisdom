import gleam/io
import eyg/ast
import eyg/ast/pattern
import eyg/typer.{infer, init, resolve}
import eyg/typer/monotype
import eyg/typer/polytype

pub fn typed_function_test() {
  let typer = init([])
  let untyped =
    ast.Function(
      "x",
      ast.Let(pattern.Tuple([]), ast.Variable("x"), ast.Binary("")),
    )
  let Ok(#(type_, typer)) = infer(untyped, typer)
  let monotype.Function(monotype.Tuple([]), monotype.Binary) =
    resolve(type_, typer)
}

pub fn generic_function_test() {
  let typer = init([])
  let untyped = ast.Function("x", ast.Variable("x"))
  let Ok(#(type_, typer)) = infer(untyped, typer)
  let monotype.Function(monotype.Unbound(a), monotype.Unbound(b)) =
    resolve(type_, typer)
  let True = a == b
}

pub fn call_function_test() {
  let typer = init([])
  let untyped =
    ast.Call(
      ast.Function(
        "x",
        ast.Let(pattern.Tuple([]), ast.Variable("x"), ast.Binary("")),
      ),
      ast.Tuple([]),
    )
  let Ok(#(type_, typer)) = infer(untyped, typer)
  let monotype.Binary = resolve(type_, typer)
}

pub fn call_generic_test() {
  let typer = init([])
  let untyped = ast.Call(ast.Function("x", ast.Variable("x")), ast.Tuple([]))
  let Ok(#(type_, typer)) = infer(untyped, typer)
  let monotype.Tuple([]) = resolve(type_, typer)
}

pub fn call_with_incorrect_argument_test() {
  let typer = init([])
  let untyped =
    ast.Call(
      ast.Function(
        "x",
        ast.Let(pattern.Tuple([]), ast.Variable("x"), ast.Binary("")),
      ),
      ast.Tuple([ast.Binary("extra argument")]),
    )
  let Error(typer.IncorrectArity(0, 1)) = infer(untyped, typer)
}