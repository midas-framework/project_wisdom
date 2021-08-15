import gleam/list
import eyg/ast.{Binary, Row, Tuple, Variable}
import eyg/typer/monotype
import eyg/typer/polytype

// Context/typer
pub type State {
  State(variables: List(#(String, polytype.Polytype)))
}

pub type Reason {
  // IncorrectArity(expected: Int, given: Int)
  UnknownVariable(label: String)
}

// CouldNotUnify(expected: Type, given: Type)
// UnhandledVarients(remaining: List(String))
// RedundantClause(match: String)
pub fn init(variables) {
  State(variables)
}

fn get_variable(label, state) {
  let State(variables) = state
  case list.key_find(variables, label) {
    Ok(polytype) -> Ok(polytype.instantiate(polytype))
    Error(Nil) -> Error(UnknownVariable(label))
  }
}

// inference fns
fn infer_field(field, typer) {
  let #(name, tree) = field
  try #(type_, typer) = infer(tree, typer)
  Ok(#(#(name, type_), typer))
}

pub fn infer(
  tree: ast.Node,
  typer: State,
) -> Result(#(monotype.Monotype, State), Reason) {
  case tree {
    Binary(_) -> Ok(#(monotype.Binary, typer))
    Tuple(elements) -> {
      try #(types, typer) = list.try_map_state(elements, typer, infer)
      Ok(#(monotype.Tuple(types), typer))
    }
    Row(fields) -> {
      try #(types, typer) = list.try_map_state(fields, typer, infer_field)
      Ok(#(monotype.Row(types), typer))
    }
    Variable(label) -> {
      try type_ = get_variable(label, typer)
      Ok(#(type_, typer))
    }
  }
}
