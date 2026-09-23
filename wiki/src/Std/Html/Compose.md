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
`whenBuilt(condition, builder: fn() -> Html)` is the separately named deferred conditional: false
returns the persistent receiver without invoking the callback; true invokes it once and appends its
typed result in order. Existing eager `when` is unchanged.
`documentShell(title, bodySlot)` and `documentShellIn(language, title, bodySlot)` build the same
typed html/head/metadata/title/body structure as a reusable [[Std Html SSR]] `Shell`, with the named
slot as the body's complete child fragment. They accept no string templates or dynamic attributes.

## Algorithm and invariants

Methods append typed nodes to persistent arrays. Text helpers always create Html.Text children;
there is no markup-string interpolation or implicit trust. `add` accepts the existing Html model,
including deliberate trust escapes. `each` calls its mapper once per item in order and appends
those nodes directly. `when` conditionally appends an already evaluated view; it is not lazy.
No hidden state, IO, new grammar or compiler handling is required. Generic elements and attributes
remain available through Html and add, so this layer does not replace the complete node model.
The document-shell helpers reuse the same fixed head construction as ordinary documents; only the
body child changes from supplied `Content` nodes to one typed slot.

## Grill Log

- **Q:** Hide nested arrays behind another template parser? **A:** No; expose a linear chain of
  content operations and ordinary named component functions using existing method dispatch.
- **Q:** Mutate shared page state? **A:** No; every step returns a persistent Content value.
- **Q:** Escape helper text before creating nodes? **A:** No; rendering performs escaping once.
- **Q:** Impose one application layout? **A:** No; document supplies a minimal shell, while
  fragment and add allow application-defined shells and components.
- **Q:** Put a string marker into the document and replace it later? **A:** No; the helper builds a
  typed `ShellElement` tree with a `ShellSlot` child, and `Std.Html.Ssr` compiles that structure.
- **Q:** Offer dynamic title, language, or attributes here? **A:** No; issue #260 admits complete
  child-fragment slots only. Callers may choose another prepared shell or construct `Shell` directly.
- **Q:** Reuse the name `when` with another parameter type? **A:** No; a separately named
  `whenBuilt` makes evaluation timing visible and avoids overload ambiguity.
- **Q:** Evaluate a false builder for validation? **A:** No; its type is checked statically, and
  runtime false means zero calls and zero constructed subtree.
- **Q:** Change trust behavior? **A:** No; the callback returns ordinary typed `Html`; deliberate
  `Trusted` values remain explicit at the callback's construction site.

## Dependencies and consumers

[[Std Html]] supplies nodes and rendering. [[Std Html SSR]] supplies typed reusable shell plans.
[[Notes Web Application]] demonstrates composition; [[Std Http Server Reply]] accepts the resulting
document. Unvalidated at user direction.

## Referenced by
[[src/Std/_MOC]] · [[2026-09-06-application-stack]] · [[2026-09-20-typed-html-shells]] ·
[[2026-09-20-deferred-html-builders]]
