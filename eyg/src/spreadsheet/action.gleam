import gleam/io
import gleam/int
import gleam/list
import lustre/cmd
import spreadsheet/state.{State}

pub type Action {
  Keypress(String)
}

pub fn update(state, action) {
  case action {
    Keypress(key) -> #(handle_keypress(state, key), cmd.none())
  }
}

fn handle_keypress(state, key) {
  let #(_, frame) = state.frame(state)
  let width = list.length(frame.headers)
  let height = list.length(frame.data)
  case key {
    "w" -> {
      let State(offset: offset, ..) = state
      let offset = int.max(offset - 1, 0)
      State(..state, offset: offset)
    }
    "s" -> {
      let State(offset: offset, ..) = state
      let offset = int.min(offset + 1, list.length(state.commits) - 1)
      State(..state, offset: offset)
    }
    "d" -> {
      let State(diff: diff, ..) = state
      State(..state, diff: !diff)
    }
    "ArrowRight" -> {
      let State(focus: #(t, x, y), ..) = state
      State(..state, focus: #(t, int.min(x + 1, width - 1), y))
    }
    "ArrowLeft" -> {
      let State(focus: #(t, x, y), ..) = state
      State(..state, focus: #(t, int.max(x - 1, 0), y))
    }
    "ArrowUp" -> {
      let State(focus: #(t, x, y), ..) = state
      State(..state, focus: #(t, x, int.max(y - 1, 0)))
    }
    "ArrowDown" -> {
      let State(focus: #(t, x, y), ..) = state
      State(..state, focus: #(t, x, int.min(y + 1, height - 1)))
    }
    "Enter" -> {
      let State(focus: #(t, x, y), ..) = state
      case t == 0 {
        True -> State(..state, focus: #(y, 0, 0))
        False -> state
      }
    }
    "Escape" -> {
      let State(focus: #(t, x, y), ..) = state
      State(..state, focus: #(0, 0, 0))
    }
    _ -> {
      io.debug(key)
      state
    }
  }
}
