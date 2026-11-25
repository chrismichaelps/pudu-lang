---
type: module
path: "@root/src/Pudu/Eval/HtmlRender.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Eval Html Render]
---
# Eval Html Render

## Purpose

The evaluator's `htmlRender(view, document)` builtin.

## Contract

Writes exactly what `Std.Html.render` (document false) and `Std.Html.document` (document true) write, by the same rules as [[Native HTML Kernel]]. A value that is not a page reports E7001; wrong arguments report E7012.

## Resolved Grill Log

The builtin is pure, so it joins the builtins a constant may be folded through.

## Referenced by

[[Native HTML Kernel]] · [[Std Html]]
