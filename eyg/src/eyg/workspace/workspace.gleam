import gleam/dynamic.{Dynamic}
import gleam/io
import gleam/list
import gleam/map
import gleam/option.{None, Option, Some}
import gleam/string
import gleam_extra
import eyg/typer/monotype as t
import eyg/ast/expression as e
import eyg/ast/pattern as p
import eyg/interpreter/interpreter
import eyg/editor/editor
import eyg/analysis
import eyg/typer
import eyg/codegen/javascript


pub type Panel {
  OnEditor
  // TODO 0 is tets suite but maybe better with enum, unlees we number mounts
  OnMounts
}

pub type App {
  App(key: String, mount: Mount(Dynamic))
}

pub type Workspace(n) {
  Workspace(
    focus: Panel,
    editor: Option(editor.Editor(n)),
    active_mount: Int,
    apps: List(App),
  )
}

// Numbered workspaces make global things like firmata connection trick can just be named
// Bench rename panel benches?
pub type Mount(a) {
  Static(value: String)
  String2String(
    input: String,
    output: String,
    func: Option(fn(String) -> String),
  )
  TestSuite(result: String)
  UI(
    initial: Option(a),
    state: Option(
      #(
        Dynamic,
        fn(Dynamic) -> Result(Dynamic, String),
        fn(Dynamic) -> Result(Dynamic, String),
      ),
    ),
    rendered: String,
  )
  Firmata(scan: Option(fn(Dynamic) -> Dynamic))
  Server(handle: Option(fn(Dynamic) -> Dynamic))
  // Only difference between server and universial is that universal works with source
  Universal(handle: Option(fn( String,  String,  String) -> String))
}

// mount handling of keydown
pub fn handle_keydown(app, key, ctrl, text) {
  let App(key, mount) = app
  // Need an init from first time we focus
  case mount {
    UI(initia, state, rendered) -> {
      io.debug("count all this state")
      app
    }
    _ -> app
  }
}

pub fn handle_input(app, data) {
  let App(key, mount) = app

  let mount = case app.mount {
    String2String(input, output, func) ->
      case func {
        None -> String2String(data, output, func)
        Some(f) -> {
          let output = f(data)
          String2String(data, output, func)
        }
      }
    _ -> todo("this app dont change here")
  }
  App(key, mount)
}

pub fn handle_click(app) {
  let App(key, mount) = app

  let mount = case app.mount {
    UI(initial, Some(#(state, update, render)), _) -> {
      assert Ok(state) = update(state)
      assert Ok(rendered) = render(state)
      assert Ok(rendered) = dynamic.string(rendered)
      UI(initial, Some(#(state, update, render)), rendered)
    }
    _ -> todo("this app dont change here")
  }
  App(key, mount)
}

pub fn dispatch_to_app(workspace: Workspace(_), function) {
  let pre = list.take(workspace.apps, workspace.active_mount)
  assert [app, ..post] = list.drop(workspace.apps, workspace.active_mount)
  let app = function(app)
  let apps = list.append(pre, [app, ..post])
  Workspace(..workspace, apps: apps)
}

pub fn mount_constraint(mount) {
  case mount {
    TestSuite(_) ->
      t.Function(
        t.Tuple([]),
        t.Union(
          // TODO t.Bool 
          variants: [#("True", t.Tuple([])), #("False", t.Tuple([]))],
          extra: None,
        ),
      )
    String2String(_, _, _) -> t.Function(t.Binary, t.Binary)
    UI(_, _, _) ->
      t.Record(
        [
          #("init", t.Function(t.Tuple([]), t.Unbound(-2))),
          #("update", t.Function(t.Unbound(-2), t.Unbound(-2))),
          #("render", t.Function(t.Unbound(-2), t.Binary)),
        ],
        None,
      )
    Firmata(_) -> {
      // TODO move boolean to standard types
      let boolean =
        t.Union([#("True", t.Tuple([])), #("False", t.Tuple([]))], None)
      let input = t.Record([], None)
      let state = t.Unbound(-2)
      let output = t.Record([#("Pin12", boolean), #("Pin13", boolean)], None)
      t.Function(t.Tuple([input, state]), t.Tuple([output, state]))
    }
    Server(_) -> t.Function(t.Binary, t.Binary)
    Universal(_) -> t.Function(
      t.Record([#("Method", t.Binary), #("Path", t.Binary), #("Body", t.Binary)], None), 
      t.Function(
        t.Record([#("OnKeypress", t.Function(t.Function(t.Binary, t.Tuple([])), t.Tuple([]))), #("render", t.Function(t.Binary, t.Tuple([]))),  #("log", t.Function(t.Binary, t.Tuple([])))], None), 
        t.Binary
      )
    )
    Static(_) -> t.Unbound(-2)
  }
}

pub fn app_constraint(app) {
  let App(key, mount) = app
  let constraint = t.Record([#(key, mount_constraint(mount))], Some(-1))
}

pub fn focus_on_mount(before: Workspace(_), index) {
  assert Ok(app) = list.at(before.apps, index)
  let constraint = app_constraint(app)
  let editor = case before.editor {
    None -> None
    Some(editor) -> {
      let editor = editor.set_constraint(editor, constraint)
      Some(editor)
    }
  }

  let workspace =
    Workspace(..before, focus: OnMounts, active_mount: index, editor: editor)
  case workspace.editor {
    Some(editor.Editor(cache: editor.Cache(evaled: Ok(code), ..), source: s ..)) -> {
      let func = code_update(code, s, _)
      dispatch_to_app(workspace, func)
    }
    _ -> workspace
  }
}

pub fn code_update(code, source, app) {
  let App(key, mount) = app
  io.debug("running the app")
  let mount = case mount {
    TestSuite(_) -> {
      let cast = gleam_extra.dynamic_function
      assert Ok(prog) = dynamic.field(key, cast)(code)
      assert Ok(r) = prog(dynamic.from([]))
      |> io.debug()
      // TODO Inner value should be tuple 0, probably should be added to gleam extra
      case dynamic.field("True", Ok)(r) {
        Ok(inner) -> TestSuite("True")
        Error(_) -> TestSuite("False")
      }
    }
    String2String(input, output, _) -> {
      let cast = gleam_extra.dynamic_function
      assert Ok(prog) = dynamic.field(key, cast)(code)
      let prog = fn(input: String) {
        assert Ok(output) = prog(dynamic.from(input))
        assert Ok(output) = dynamic.string(output)
        output
      }
      let output = prog(input)
      String2String(input, output, Some(prog))
    }
    Firmata(_) -> {
      let cast = gleam_extra.dynamic_function
      assert Ok(scan) = dynamic.field(key, cast)(code)
      Firmata(Some(fn(x) {
        assert Ok(returned) = scan(x)
        returned
      }))
    }
    UI(initial, state, rendered) -> {
      assert Ok(record) = dynamic.field(key, Ok)(code)
      let cast = gleam_extra.dynamic_function
      assert Ok(init) = dynamic.field("init", cast)(record)
      assert Ok(update) = dynamic.field("update", cast)(record)
      assert Ok(render) = dynamic.field("render", cast)(record)
      assert Ok(new_initial) = init(dynamic.from([]))
      case Some(new_initial) == initial {
        False -> {
          let initial = new_initial
          let state = new_initial
          assert Ok(rendered) = render(state)
          assert Ok(rendered) = dynamic.string(rendered)
          UI(Some(new_initial), Some(#(state, update, render)), rendered)
        }
        True -> {
          assert Some(#(state, _update, _render)) = state
          assert Ok(rendered) = render(state)
          let state = Some(#(state, update, render))
          assert Ok(rendered) = dynamic.string(rendered)
          UI(initial, state, rendered)
        }
      }
    }
    Static(_) -> todo("probably remove I don't see much value in static")
    Server(_) -> {
      let cast = gleam_extra.dynamic_function
      assert Ok(handle) = dynamic.field(key, cast)(code)
      Server(Some(fn(x) {
        assert Ok(returned) = handle(x)
        returned
      }))
    }
    Universal(_) -> {
      // TODO this looses scope but issues with rewritting harness
      // Need to shake tree
      // assert #(_, e.Record(fields)) = last_term(source)
      // assert Ok(server_source) = list.key_find(fields, key) 
      let server_source = e.access(source, key)

      // rerender as a function same as capture
      // Pass in dom arguments
      // on click at all times
      // Need mutable ref or app state

      let handler = fn (method, path, body) { 
        let #(typed, typer) = analysis.infer(server_source, t.Unbound(-1), [])
        let #(typed, typer) = typer.expand_providers(typed, typer, [])

        let top_env = map.new()
        |> map.insert("harness", interpreter.Record([
          #("compile", interpreter.Function(p.Variable(""), e.tagged("Error", e.binary("not in interpreter")), map.new(), None)), 
          #("debug", interpreter.BuiltinFn(io.debug))
        ]))
// We expand the providers but the exec needs dynamic
        let server_arg = interpreter.Record([#("Method", interpreter.Binary(method)),#("Path", interpreter.Binary(path)),#("Body", interpreter.Binary(body))])
        assert interpreter.Function(pattern, body, captured, _) = interpreter.exec(editor.untype(typed), top_env)

        // eval server fn with arg
        // can definetly make a call with request as a named call arg
        let inner = interpreter.extend_env(captured, pattern, server_arg)

        // client function
        assert interpreter.Function(pattern, body, captured, _) =  interpreter.exec(body, inner)
        let client_source = e.function(pattern, body)
        
        // TODO captured should not include empty
        let #(typed, typer) = analysis.infer(client_source, t.Unbound(-1), [])
        let #(typed, typer) = typer.expand_providers(typed, typer, [])

        let program = list.map(map.to_list(captured), interpreter.render_var)
        |> list.append([javascript.render_to_string(typed, typer)])
        |> string.join("\n")
        |> string.append("({
OnKeypress: (f) => document.addEventListener(\"keydown\", function (event) {
    f(event.key);
  }),
render: (value) => document.body.innerHTML = value,
log: (x) => console.log(x),
});")
string.concat(["<head></head><body></body><script>", program, "</script>"])
      }
      Universal(Some(handler))
    }
  }
  App(key, mount)
}

// TODO REPL in place in tree as app

fn last_term(source) { 
  let #(_, tree) = source
  case tree {
    e.Let(_,_, then) -> last_term(then) 
    _ -> source
  }
 }

// CLI
// ScanCycle
// TODO add inspect to std lib
external fn inspect_gleam(a) -> String =
  "../../gleam" "inspect"

external fn inspect(a) -> String =
  "" "JSON.stringify"
