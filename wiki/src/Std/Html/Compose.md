---
type: module
path: "@root/lib/Std/Html/Compose.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, html]
aliases: [Std Html Compose]
---
# Std Html Compose

## Purpose and interface

Fluent, persistent content composition. `content()` returns Content with an empty node array.
The exported Composition trait provides heading(level, text), paragraph(text), preformatted(text),
add(Html), each(Array[T], fn(T)->Html), when(Bool, Html), fragment(), article() and section().
Each adding method returns new Content, preserving earlier values and insertion order. Terminal
methods produce existing Html values. `document(title, Content)` supplies html/head/title/UTF-8
metadata/body; the reply layer remains responsible for adding a doctype through Reply.page.
`documentIn(language, title, Content)` additionally sets the html language attribute.

## Algorithm and invariants

Methods append typed nodes to persistent arrays. Text helpers always create Html.Text children;
there is no markup-string interpolation or implicit trust. `add` accepts the existing Html model,
including deliberate trust escapes. `each` calls its mapper once per item in order and appends
those nodes directly. `when` conditionally appends an already evaluated view; it is not lazy.
No hidden state, IO, new grammar or compiler handling is required. Generic elements and attributes
remain available through Html and add, so this layer does not replace the complete node model.

## Grill Log

- **Q:** Hide nested arrays behind another template parser? **A:** No; expose a linear chain of
  content operations and ordinary named component functions using existing method dispatch.
- **Q:** Mutate shared page state? **A:** No; every step returns a persistent Content value.
- **Q:** Escape helper text before creating nodes? **A:** No; rendering performs escaping once.
- **Q:** Impose one application layout? **A:** No; document supplies a minimal shell, while
  fragment and add allow application-defined shells and components.

## Dependencies and consumers

[[Std Html]] supplies nodes and rendering. [[Notes Web Application]] demonstrates composition;
[[Std Http Server Reply]] accepts the resulting document. Unvalidated at user direction.

## Referenced by
[[src/Std/_MOC]] · [[2026-09-06-application-stack]]
