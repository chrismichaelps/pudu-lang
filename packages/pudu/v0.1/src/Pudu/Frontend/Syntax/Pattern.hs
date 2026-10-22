{-| @Syntax.Pattern — names introduced by one successful pattern path. -}
module Pudu.Frontend.Syntax.Pattern (patternBindings) where

import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (ArrayRest (..), FieldPattern (..), Pattern (..))

{-| Alternatives expose their first branch's bindings. Resolution checks
    that every other branch introduces the same names. Duplicates inside a
    branch remain visible so they can be diagnosed rather than erased. -}
patternBindings :: Located Pattern -> [Located Text]
patternBindings (Located _ pattern') = case pattern' of
  BindingPattern name -> [name]
  TuplePattern members -> concatMap patternBindings members
  ConstructorPattern _ members -> concatMap patternBindings members
  ArrayPattern prefix rest suffix ->
    concatMap patternBindings prefix <> restBindings rest <> concatMap patternBindings suffix
  RecordPattern _ fields _ -> concatMap fieldBindings fields
  AlternativePattern (first : _) -> patternBindings first
  _ -> []
 where
  restBindings (Just (BoundRest name)) = [name]
  restBindings _ = []
  fieldBindings (Located _ field) =
    maybe [fieldPatternName field] patternBindings (fieldPatternValue field)
