import gleam/io
import gleam/list
import language/ast.{
  Assignment, Binary, Call, Case, Destructure, Fn, Let, NewData, Row, RowPattern,
  Tuple, TuplePattern, Var,
}
import language/type_.{Type}

pub fn int_to_string(int) {
  do_to_string(int)
}

if erlang {
  external fn do_to_string(Int) -> String =
    "erlang" "integer_to_binary"
}

if javascript {
  external fn do_to_string(Int) -> String =
    "" "Number.prototype.toString.call"
}

fn map_first(list, func) {
  case list {
    [first, ..rest] -> [func(first), ..rest]
    _ -> todo("map first didn't do anything")
  }
}

fn map_last(list, func) {
  list
  |> list.reverse()
  |> map_first(func)
  |> list.reverse()
}

fn indent(lines) {
  list.map(lines, fn(line) { concat(["  ", line]) })
}

fn wrap(pre, lines, post) {
  case lines {
    [] -> [concat([pre, post])]
    _ ->
      lines
      |> map_first(fn(first) { concat([pre, first]) })
      |> map_last(fn(last) { concat([last, post]) })
  }
}

fn squash(a, b) {
  let [join, ..rest] = b
  map_last(a, fn(last) { concat([last, join]) })
  |> list.append(rest)
}

fn render_label(quantified_label) {
  let #(label, count) = quantified_label
  concat([label, "$", int_to_string(count)])
}

fn wrap_return(lines, in_tail) {
  case in_tail {
    True -> wrap("return ", lines, ";")
    False -> lines
  }
}

pub fn intersperse(list: List(a), delimeter: a) -> List(a) {
  case list {
    [] -> []
    [one, ..rest] -> do_intersperse(rest, delimeter, [one])
  }
}

fn do_intersperse(list, delimeter, accumulator) {
  case list {
    [] -> list.reverse(accumulator)
    [item, ..list] ->
      do_intersperse(list, delimeter, [item, delimeter, ..accumulator])
  }
}

fn strip_type(typed) {
  let #(_, tree) = typed
  tree
}

fn render_destructure(args) {
  list.map(args, render_label)
  |> fn(args) {
    case args {
      [] -> [""]
      args -> args
    }
  }
  |> intersperse(", ")
  |> wrap("[", _, "]")
  |> concat()
}

pub fn maybe_wrap_expression(expression) {
  case expression {
    // let is always at least two lines
    #(_, Let(_, _, _)) | #(_, NewData(_,_,_,_)) -> {
      let rendered = render(expression, True)
      ["(() => {"]
      |> list.append(indent(rendered))
      |> list.append(["})()"])
    }
    _ -> render(expression, False)
  }
}

fn wrap_single_or_multiline(terms, delimeter, before, after) {
  let grouped =
    list.fold(
      terms,
      Ok([]),
      fn(lines, state) {
        case state {
          Ok(singles) ->
            case lines {
              [single] -> Ok([single, ..singles])
              multi -> {
                let previous = list.map(singles, fn(s) { [s] })
                Error([multi, ..previous])
              }
            }
          Error(multis) -> Error([lines, ..multis])
        }
      },
    )
  case grouped {
    Ok(singles) -> {
      let values_string =
        singles
        |> list.reverse()
        |> intersperse(concat([delimeter, " "]))
        |> wrap(before, _, after)
        |> concat()
      [values_string]
    }
    Error(multis) -> {
      let lines =
        multis
        |> list.reverse()
        |> list.map(wrap("", _, delimeter))
        |> list.flatten()
        |> indent()
      let lines =
        [before]
        |> list.append(lines)
        |> list.append([after])
      lines
    }
  }
}

// Needs to define the type of first element in the typed tuple as it is never defined and that causes a compiler bug
pub fn render(typed: #(Type, ast.Expression(Type, #(String, Int))), in_tail) {
  case typed {
    #(_, NewData(_type_name, _params, constructors, in)) ->
      list.map(
        constructors,
        fn(constructor) {
          let #(label, _arguments) = constructor
          // names are unique within the checked type
          let #(name, _) = label
          concat([
            "let ",
            render_label(label),
            " = ((...args) => Object.assign({ type: \"",
            name,
            "\" }, args));",
          ])
        },
      )
      |> list.append(render(in, in_tail))
    #(_, Let(pattern, value, in)) -> {
      let value = maybe_wrap_expression(value)
      let value = case pattern {
        Assignment(label) -> {
          let assignment = concat(["let ", render_label(label), " = "])
          wrap(assignment, value, ";")
        }
        TuplePattern(assignments) -> {
          let assignment =
            concat(["let ", render_destructure(assignments), " = "])
          wrap(assignment, value, ";")
        }
        RowPattern(rows) -> {
          let assignment =
            list.map(
              rows,
              fn(row) {
                let #(row_name, label) = row
                concat([row_name, ": ", render_label(label)])
              },
            )
            |> intersperse(", ")
            |> wrap("{", _, "}")
            |> concat()
          let assignment = concat(["let ", assignment, " = "])
          wrap(assignment, value, ";")
        }
        Destructure(_name, args) -> {
          let assignment = concat(["let ", render_destructure(args), " = "])
          wrap(assignment, wrap("Object.values(", value, ")"), ";")
        }
      }
      list.append(value, render(in, in_tail))
    }
    #(_, Var(label)) -> wrap_return([render_label(label)], in_tail)
    #(_, Case(subject, clauses)) -> {
      let #(lines, _) =
        list.fold(
          clauses,
          #([], True),
          fn(clause, state) {
            let #(accumulator, first) = state
            let pre = case first {
              True -> "if"
              False -> "} else if"
            }
            let #(pattern, then) = clause
            let [l1, l2] = case pattern {
              Destructure(name, args) -> [
                concat([pre, " (subject.type == \"", name, "\") {"]),
                concat([
                  "  let ",
                  render_destructure(args),
                  " = Object.values(subject);",
                ]),
              ]
              Assignment(label) -> [
                "} else {",
                concat(["  let ", render_label(label), " = subject;"]),
              ]
            }
            #(
              list.append(accumulator, [l1, l2, ..indent(render(then, True))]),
              False,
            )
          },
        )
      let lines =
        ["((subject) => {", ..lines]
        |> list.append(["}})"])
      let subject = wrap("(", maybe_wrap_expression(subject), ")")
      squash(lines, subject)
      |> wrap_return(in_tail)
    }
    // TODO escape
    #(_, Binary(content)) ->
      wrap_return([concat(["\"", content, "\""])], in_tail)
    #(_, Tuple(values)) ->
      list.map(values, maybe_wrap_expression)
      |> wrap_single_or_multiline(",", "[", "]")
      |> wrap_return(in_tail)
    #(_, Row(rows)) ->
      list.map(
        rows,
        fn(row) {
          let #(name, value) = row
          wrap(concat([name, ": "]), maybe_wrap_expression(value), "")
        },
      )
      |> wrap_single_or_multiline(",", "{", "}")
      |> wrap_return(in_tail)
    #(_, Fn(args, in)) -> {
      let args = list.map(args, strip_type)
      let args_string =
        list.map(args, render_label)
        |> intersperse(", ")
        |> concat()
      let start = concat(["((", args_string, ") => {"])
      case render(in, True) {
        [single] -> [concat([start, " ", single, " })"])]
        lines ->
          [start, ..indent(lines)]
          |> list.append(["})"])
      }
      |> wrap_return(in_tail)
    }
    #(_, Call(function, with)) -> {
      let function = render(function, False)
      let with = list.map(with, maybe_wrap_expression)
      let args_string = wrap_single_or_multiline(with, ",", "(", ")")
      squash(function, args_string)
      |> wrap_return(in_tail)
    }
  }
}

if javascript {
  pub external fn concat(List(String)) -> String =
    "../../helpers.js" "concat"
}

if erlang {
  pub external fn concat(List(String)) -> String =
    "unicode" "characters_to_binary"
}
