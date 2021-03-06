import gleam/list
import gleam/order

pub fn root() {
  []
}

// maybe path.child
pub fn append(path, i) {
  list.append(path, [i])
}

pub fn parent(path) {
  case list.reverse(path) {
    [] -> Error(Nil)
    [last, ..rest] -> Ok(#(list.reverse(rest), last))
  }
}

pub fn order(a, b) {
  case a, b {
    [], [] -> order.Eq
    [x, ..], [y, ..] if x < y -> order.Lt
    [x, ..], [y, ..] if x > y -> order.Gt
    [], [_, ..] -> order.Lt
    [_, ..], [] -> order.Gt
    [x, ..a], [y, ..b] if x == y -> order(a, b)
  }
}
