import eyg/ast
import eyg/ast/pattern
import eyg/typer/monotype
import standard/builders.{clause, function}

pub fn code() {
  ast.Name(
    #(
      "Boolean",
      #([], [#("True", monotype.Tuple([])), #("False", monotype.Tuple([]))]),
    ),
    ast.Name(
      #(
        "Option",
        #(
          [1],
          [
            #("Some", monotype.Tuple([monotype.Unbound(1)])),
            #("None", monotype.Tuple([])),
          ],
        ),
      ),
      ast.Let(
        pattern.Variable("t"),
        ast.Call(ast.Constructor("Boolean", "True"), ast.Tuple([])),
        ast.Let(
          pattern.Variable("and"),
          function(
            ["left", "right"],
            ast.Case(
              "Boolean",
              ast.Variable("left"),
              [
                clause("True", [], ast.Variable("right")),
                clause(
                  "False",
                  [],
                  ast.Call(ast.Constructor("Boolean", "False"), ast.Tuple([])),
                ),
              ],
            ),
          ),
          ast.Binary("banana"),
        ),
      ),
    ),
  )
}

pub fn test() {
  ast.Let(
    pattern.Row([
      #("and", "and"),
      #("or", "or"),
      #("True", "True"),
      #("False", "False"),
    ]),
    ast.Variable("boolean"),
    ast.Let(
      pattern.Variable("should$equal"),
      function(
        ["given", "expected"],
        ast.Case(
          "Boolean",
          ast.Call(
            ast.Variable("equal"),
            ast.Tuple([ast.Variable("given"), ast.Variable("expected")]),
          ),
          [
            clause("True", [], ast.Tuple([])),
            clause(
              "False",
              [],
              ast.Call(
                ast.Variable("hole"),
                ast.Tuple([ast.Binary("Should equal")]),
              ),
            ),
          ],
        ),
      ),
      ast.Call(
        ast.Variable("should$equal"),
        ast.Tuple([
          ast.Variable("True"),
          ast.Call(
            ast.Variable("and"),
            ast.Tuple([ast.Variable("True"), ast.Variable("True")]),
          ),
        ]),
      ),
    ),
  )
}