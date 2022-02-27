import gleam/io
import gleam/option.{None, Some}
import gleam/list
import eyg/typer/monotype as t

pub type Polytype(n) {
  Polytype(forall: List(Int), monotype: t.Monotype(n))
}

// take in an i for the offset
// is there a name for the unification/constraints
pub fn instantiate(polytype, next_unbound) {
  let Polytype(forall, monotype) = polytype
  do_instantiate(forall, monotype, next_unbound)
}

fn do_instantiate(forall, monotype, next_unbound) {
  case forall {
    [] -> #(monotype, next_unbound)
    [variable, ..forall] -> {
      let monotype = replace_variable(monotype, variable, next_unbound)
      do_instantiate(forall, monotype, next_unbound + 1)
    }
  }
}

pub fn replace_variable(monotype, x, y) {
  case monotype {
    t.Native(name) -> t.Native(name)
    t.Binary -> t.Binary
    t.Tuple(elements) -> t.Tuple(list.map(elements, replace_variable(_, x, y)))
    t.Record(fields, rest) -> {
      let fields =
        list.map(
          fields,
          fn(field) {
            let #(name, value) = field
            #(name, replace_variable(value, x, y))
          },
        )
      let rest = case rest {
        Some(i) if i == x -> Some(y)
        _ -> rest
      }
      t.Record(fields, rest)
    }
    t.Union(variants, rest) -> {
      let variants =
        list.map(
          variants,
          fn(variant) {
            let #(name, value) = variant
            #(name, replace_variable(value, x, y))
          },
        )
      let rest = case rest {
        Some(i) if i == x -> Some(y)
        _ -> rest
      }
      t.Union(variants, rest)
    }
    t.Function(from, to) ->
      t.Function(replace_variable(from, x, y), replace_variable(to, x, y))
    t.Unbound(i) ->
      case i == x {
        True -> t.Unbound(y)
        False -> t.Unbound(i)
      }
  }
}

// maybe scope builds atop polytype
// MUST BE resolved first
pub fn generalise(monotype, variables) {
  case monotype {
    t.Function(_from, _to) -> {
      let in_type = free_variables_in_monotype(monotype)
      let in_scope = free_variables_in_scope(variables)
      Polytype(difference(in_type, in_scope), monotype)
    }
    _ -> Polytype([], monotype)
  }
}

fn free_variables_in_scope(variables) {
  list.fold(
    variables,
    [],
    fn(free, variable) {
      let #(_label, polytype) = variable
      free_variables_in_polytype(polytype)
      |> union(free)
    },
  )
}

fn free_variables_in_polytype(polytype) {
  let Polytype(quantified, monotype) = polytype
  free_variables_in_monotype(monotype)
  |> difference(quantified)
}

fn free_variables_in_monotype(monotype) {
  case monotype {
    t.Native(_) -> []
    t.Binary -> []
    t.Tuple(elements) ->
      list.fold(
        elements,
        [],
        fn(accumulator, element) {
          union(free_variables_in_monotype(element), accumulator)
        },
      )
    t.Record(fields, extra) -> free_variables_in_row(fields, extra)
    t.Union(variants, extra) -> free_variables_in_row(variants, extra)
    t.Function(from, to) ->
      union(free_variables_in_monotype(from), free_variables_in_monotype(to))
    t.Unbound(i) -> [i]
  }
}

fn free_variables_in_row(rows, extra) {
  let in_rows =
    list.fold(
      rows,
      [],
      fn(accumulator, row) {
        let #(_name, value) = row
        union(free_variables_in_monotype(value), accumulator)
      },
    )
  case extra {
    Some(i) -> push_new(i, in_rows)
    None -> in_rows
  }
}

fn difference(items: List(a), excluded: List(a)) -> List(a) {
  do_difference(items, excluded, [])
}

fn do_difference(items, excluded, accumulator) {
  case items {
    [] -> list.reverse(accumulator)
    [next, ..items] ->
      case list.find(excluded, fn(i) { i == next }) {
        Ok(_) -> do_difference(items, excluded, accumulator)
        Error(_) -> push_new(next, accumulator)
      }
  }
}

fn union(new: List(a), existing: List(a)) -> List(a) {
  case new {
    [] -> existing
    [next, ..new] -> {
      let existing = push_new(next, existing)
      union(new, existing)
    }
  }
}

fn push_new(item: a, set: List(a)) -> List(a) {
  case list.find(set, fn(i) { i == item }) {
    Ok(_) -> set
    Error(Nil) -> [item, ..set]
  }
}
