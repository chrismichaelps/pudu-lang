{-| @Pudu.Backend.Emit.Aggregate — owned cells, aggregate helper names, and
    the per-type tuple, record and sum helpers a program actually calls.

    Helper needs travel in the emitter's ordinary need set as `agg_make:X`,
    `agg_show:X`, `agg_equal:X`, `agg_compare:X` and `agg_name:X`, where X is
    the type's mangled name; a sum has one `agg_makeN:X` per variant.
    `aggregateSection` turns the ones it sees into C and reports which
    runtime parts those helpers lean on.

    A sum's box holds the variant's index in its first cell and the payload
    after it, so payload member i is cell i + 1. -}
module Pudu.Backend.Emit.Aggregate
  ( ownedType, ownedKinds, retained, released, cType, cellName, memberRender, memberComparable, isAggregate
  , aggregateHelper, aggregateNeed, aggregateTypes, aggregateSection
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Cell
  ( aggregateHelper, aggregateNeed, cType, cellName, isAggregate, memberCompare, memberComparable
  , memberEqual, memberRender, number, ownedType, released, retained )
import Pudu.Backend.Emit.Array (arrayHelpers)
import Pudu.Backend.Emit.Keyed (mapHelpers, setHelpers)
import Pudu.Backend.Emit.Range (rangeHelpers)
import Pudu.Backend.Emit.Bytes (bytesHelpers)
import Pudu.Backend.Emit.State (cString, cStringBytes)
import Pudu.Core (CoreClosureInfo (..), CoreLayout (..), CoreType (..), CoreVariant (..), displayName)
import Pudu.Core.Frame (FrameFunction (..), FrameModule (..), FrameSlot (..))

type Layouts = Map CoreType CoreLayout

{-| Every aggregate type a frame mentions, in first-seen order. Recursive
    types make "members first" impossible in general, so every helper is
    declared before any is defined. -}
aggregateTypes :: FrameModule -> [CoreType]
aggregateTypes source = reverse (foldl collect [] slotTypes)
 where
  layouts = frameModuleLayouts source
  slotTypes = concat
    [ frameFunctionResult function : map frameSlotType (frameFunctionParameters function <> frameFunctionSlots function)
    | function <- frameModuleFunctions source ]
  collect found kind
    | kind `elem` found || not (isAggregate kind) = found
    | otherwise = foldl collect (kind : found) (aggregateMembers layouts kind)

{-| Everything a value of the type can hold, every variant's payload for a sum. -}
aggregateMembers :: Layouts -> CoreType -> [CoreType]
aggregateMembers layouts kind = case (kind, Map.lookup kind layouts) of
  (CoreTupleType members, _) -> members
  (CoreArrayType element, _) -> [element]
  -- entries() answers (key, value) tuples, so a map's helpers need theirs.
  (CoreMapType key value, _) -> [key, value, CoreTupleType [key, value]]
  (CoreSetType member, _) -> [member]
  (_, Just (CoreRecordLayout fields)) -> map snd fields
  (_, Just (CoreSumLayout variants)) -> concatMap (map snd . coreVariantFields) variants
  (_, Just (CoreClosureLayout entries)) -> concatMap (closureCaptures . snd) entries
  _ -> []

{-| Ownership kinds the frame engine switches on: 1 is text, then each
    aggregate type in `aggregateTypes` order. -}
ownedKinds :: [CoreType] -> [(CoreType, Int)]
ownedKinds tuples = (CoreTextType, 1) : zip tuples [2 ..]

{-| The helpers the needs name, their own needs included, in an order where
    each comes after what it calls; and the runtime parts they use. Drop
    helpers are always written, since the frame engine releases every owned
    slot through them. -}
aggregateSection :: Map Text Int -> Layouts -> [CoreType] -> Set Text -> ([Text], Set Text)
aggregateSection identities layouts tuples needs = (concat prototypes <> concat chosen, runtime)
 where
  wanted = close (Set.fromList ([aggregateNeed "drop" kind | kind <- tuples]
    <> filter ("agg_" `Text.isPrefixOf`) (Set.toList needs)))
  close found =
    let next = Set.union found (Set.fromList (concat [helperNeeds name | name <- Set.toList found]))
     in if next == found then found else close next
  helperNeeds name = filter ("agg_" `Text.isPrefixOf`) (maybe [] fst (lookup name catalogue))
  selected = [(name, body) | (name, (_, body)) <- catalogue, Set.member name wanted]
  -- A definition's first line ending in "{" is its signature; declaring them
  -- all first lets recursive types call each other's helpers.
  prototypes = [[Text.dropEnd 2 header <> ";"] | (_, body) <- selected, header : _ <- [filter (" {" `Text.isSuffixOf`) body]]
  chosen = map snd selected
  runtime = Set.fromList (concat [filter (not . ("agg_" `Text.isPrefixOf`)) (fst entry)
    | (name, entry) <- catalogue, Set.member name wanted])
  catalogue = concat [helpers identities layouts kind | kind <- tuples]

helpers :: Map Text Int -> Layouts -> CoreType -> [(Text, ([Text], [Text]))]
helpers identities layouts kind = case (kind, Map.lookup kind layouts) of
  (CoreTupleType members, _) -> helpersOf kind (zip (map (Text.pack . show) [0 :: Int ..]) members) Nothing
  (CoreRecordType name _, Just (CoreRecordLayout fields)) -> helpersOf kind fields (Just (displayName name))
  (CoreSumType _ _, Just (CoreSumLayout variants)) -> sumHelpers kind variants
  (CoreArrayType element, _) -> arrayHelpers kind element
  (CoreMapType key value, _) -> mapHelpers kind key value
  (CoreSetType member, _) -> setHelpers kind member
  (CoreRangeType, _) -> rangeHelpers kind
  (CoreBytesType, _) -> bytesHelpers kind
  (CoreFunctionType _ _, Just (CoreClosureLayout entries)) -> closureHelpers kind
    [(identity, info) | (key, info) <- entries, Just identity <- [Map.lookup key identities]]
  _ -> []

{-| Closures: cell 0 is the function the closure runs, the captures follow.
    Drop and show switch on it. Two closures are equal when they were written
    in the same place, so equality compares sites rather than functions, the
    way the evaluator leaves captures out of a closure's identity. -}
closureHelpers :: CoreType -> [(Int, CoreClosureInfo)] -> [(Text, ([Text], [Text]))]
closureHelpers kind entries =
  [ (aggregateNeed "drop" kind, ([aggregateNeed "drop" member | (_, info) <- entries, member <- closureCaptures info, isAggregate member],
      [ "static void " <> aggregateHelper "drop" kind <> "(pudu_box *box) {"
      , "  if (box == NULL || --box->count != 0) return;"
      , "  switch (box->fields[0].scalar) {" ]
      <> concat [ ["    case " <> number identity <> ":"]
                  <> [ "      " <> released member (capture "box" position member) | (position, member) <- captures info, ownedType member ]
                  <> ["      break;"]
                | (identity, info) <- entries ]
      <> [ "    default: break;", "  }", "  free(box);", "}" ]))
  , (aggregateNeed "show" kind, (["text_literal"],
      [ "static pudu_text " <> aggregateHelper "show" kind <> "(pudu_box *box) {"
      , "  switch (box->fields[0].scalar) {" ]
      <> [ "    case " <> number identity <> ": return pudu_text_literal(" <> cString shown <> ", " <> number (cStringBytes shown) <> ");"
         | (identity, info) <- entries, let shown = "<fn " <> closureDisplayName info <> ">" ]
      <> [ "    default: return pudu_text_literal(\"\", 0);", "  }", "}" ]))
  , (aggregateNeed "comparable" kind, ([],
      [ "static int " <> aggregateHelper "comparable" kind <> "(pudu_box *box) {", "  (void)box;", "  return 0;", "}" ]))
  , (aggregateNeed "compare" kind, ([],
      [ "static int " <> aggregateHelper "compare" kind <> "(pudu_box *a, pudu_box *b) {", "  (void)a; (void)b;", "  return 0;", "}" ]))
  , (aggregateNeed "equal" kind, ([],
      [ "static int " <> aggregateHelper "site" kind <> "(pudu_box *box) {"
      , "  switch (box->fields[0].scalar) {" ]
      <> [ "    case " <> number identity <> ": return " <> number (siteNumber info) <> ";" | (identity, info) <- entries ]
      <> [ "    default: return -1;", "  }", "}"
         , "static int " <> aggregateHelper "equal" kind <> "(pudu_box *a, pudu_box *b) {"
         , "  return " <> aggregateHelper "site" kind <> "(a) == " <> aggregateHelper "site" kind <> "(b);", "}" ]))
  ] <>
  [ (aggregateNeed ("closure" <> number identity) kind, (concat [snd (retained member "") | (_, member) <- captures info],
      [ "static pudu_box *" <> aggregateHelper ("closure" <> number identity) kind <> "("
          <> (if null (captures info) then "void" else Text.intercalate ", " [cType member <> " m" <> number position | (position, member) <- captures info]) <> ") {"
      , "  pudu_box *box = pudu_box_new(" <> number (1 + length (captures info)) <> ");"
      , "  box->fields[0].scalar = " <> number identity <> ";" ]
      <> [ "  " <> capture "box" position member <> " = " <> fst (retained member ("m" <> number position)) <> ";" | (position, member) <- captures info ]
      <> [ "  return box;", "}" ]))
  | (identity, info) <- entries ]
 where
  captures info = zip [0 :: Int ..] (closureCaptures info)
  capture box position member = box <> "->fields[" <> number (position + 1) <> "]." <> cellName member
  sites = foldr (\site found -> if site `elem` found then found else site : found) [] [closureSite info | (_, info) <- entries]
  siteNumber info = length (takeWhile (/= closureSite info) sites)

{-| Tuples and records: one shape, members in cells 0.. -}
helpersOf :: CoreType -> [(Text, CoreType)] -> Maybe Text -> [(Text, ([Text], [Text]))]
helpersOf kind labelled recordName =
  [ (aggregateNeed "drop" kind, ([aggregateNeed "drop" member | member <- members, isAggregate member],
      [ "static void " <> aggregateHelper "drop" kind <> "(pudu_box *box) {"
      , "  if (box == NULL || --box->count != 0) return;" ]
      <> [ "  " <> released member (field index member) | (index, member) <- indexed, ownedType member ]
      <> [ "  free(box);", "}" ]))
  , (aggregateNeed "make" kind, (concat [snd (retained member "") | member <- members],
      [ "static pudu_box *" <> aggregateHelper "make" kind <> "("
          <> (if null members then "void" else Text.intercalate ", " [cType member <> " m" <> number index | (index, member) <- indexed]) <> ") {"
      , "  pudu_box *box = pudu_box_new(" <> number (length members) <> ");" ]
      <> [ "  " <> field index member <> " = " <> fst (retained member ("m" <> number index)) <> ";" | (index, member) <- indexed ]
      <> [ "  return box;", "}" ]))
  , (aggregateNeed "show" kind, ("text_join" : concat [snd (memberRender member "") | member <- members],
      if null members
        then [ "static pudu_text " <> aggregateHelper "show" kind <> "(pudu_box *box) {"
             , "  (void)box;"
             , "  return pudu_text_join(" <> opening <> ", NULL, NULL, 0, \"" <> closing <> "\");", "}" ]
        else [ "static pudu_text " <> aggregateHelper "show" kind <> "(pudu_box *box) {"
             , "  pudu_text parts[" <> number (length members) <> "];" ]
          <> [ "  parts[" <> number index <> "] = " <> fst (memberRender member (field index member)) <> ";" | (index, member) <- indexed ]
          <> [ "  return pudu_text_join(" <> opening <> ", " <> labels <> ", parts, " <> number (length members) <> ", \"" <> closing <> "\");", "}" ]))
  , (aggregateNeed "equal" kind, (concat [snd (memberEqual member "" "") | member <- members],
      [ "static int " <> aggregateHelper "equal" kind <> "(pudu_box *a, pudu_box *b) {"
      , if null members then "  (void)a; (void)b; return 1;"
          else "  return " <> Text.intercalate "\n    && " [fst (memberEqual member (on "a" index member) (on "b" index member)) | (index, member) <- indexed] <> ";"
      , "}" ]))
  , (aggregateNeed "comparable" kind, (concat [snd (memberComparable member "") | member <- members],
      [ "static int " <> aggregateHelper "comparable" kind <> "(pudu_box *box) {"
      , if not (any isAggregate members) then "  (void)box; return 1;"
          else "  return " <> Text.intercalate "\n    && " [fst (memberComparable member (field index member)) | (index, member) <- indexed, isAggregate member] <> ";"
      , "}" ]))
  , (aggregateNeed "compare" kind, (concat [snd (memberCompare member "" "") | member <- members],
      [ "/* compareValues: the first member that differs decides. */"
      , "static int " <> aggregateHelper "compare" kind <> "(pudu_box *a, pudu_box *b) {"
      -- Function members never decide an order, so a and b may go unread.
      , if null members then "  (void)a; (void)b;" else "  int order;\n  (void)a; (void)b;" ]
      <> concat [ [ "  order = " <> fst (memberCompare member (on "a" index member) (on "b" index member)) <> ";"
                  , "  if (order != 0) return order;" ] | (index, member) <- indexed ]
      <> [ "  return 0;", "}" ]))
  ]
 where
  members = map snd labelled
  indexed = zip [0 :: Int ..] members
  -- renderValue: (a, b) for a tuple, Name{x: a, y: b} for a record.
  (opening, labels, closing) = case recordName of
    Just name ->
      ( cString (name <> "{")
      , "(const char *const[]){" <> Text.intercalate ", " [cString (label <> ": ") | (label, _) <- labelled] <> "}"
      , "}" )
    Nothing -> ("\"(\"", "NULL", ")")
  field index member = on "box" index member
  on box index member = box <> "->fields[" <> number index <> "]." <> cellName member

{-| Sums: cell 0 is the variant index, the payload follows. Each variant gets
    its own make; drop, show and equal switch on the index. -}
sumHelpers :: CoreType -> [CoreVariant] -> [(Text, ([Text], [Text]))]
sumHelpers kind variants =
  [ (aggregateNeed "drop" kind, ([aggregateNeed "drop" member | member <- allMembers, isAggregate member],
      [ "static void " <> aggregateHelper "drop" kind <> "(pudu_box *box) {"
      , "  if (box == NULL || --box->count != 0) return;"
      , "  switch (box->fields[0].scalar) {" ]
      <> concat [ ["    case " <> number tag <> ":"]
                  <> [ "      " <> released member (payload "box" position member) | (position, member) <- members variant, ownedType member ]
                  <> ["      break;"]
                | (tag, variant) <- tagged ]
      <> [ "    default: break;", "  }", "  free(box);", "}" ]))
  , (aggregateNeed "show" kind, ("text_join" : "text_literal" : concat [snd (memberRender member "") | member <- allMembers],
      [ "static pudu_text " <> aggregateHelper "show" kind <> "(pudu_box *box) {"
      , "  pudu_text parts[" <> number (maximum (1 : [length (coreVariantFields variant) | variant <- variants])) <> "];"
      , "  switch (box->fields[0].scalar) {" ]
      <> concat [ showVariant tag variant | (tag, variant) <- tagged ]
      <> [ "    default: break;", "  }", "  (void)parts;", "  return pudu_text_literal(\"\", 0);", "}" ]))
  , (aggregateNeed "equal" kind, (concat [snd (memberEqual member "" "") | member <- allMembers],
      [ "static int " <> aggregateHelper "equal" kind <> "(pudu_box *a, pudu_box *b) {"
      , "  if (a->fields[0].scalar != b->fields[0].scalar) return 0;"
      , "  switch (a->fields[0].scalar) {" ]
      <> concat [ [ "    case " <> number tag <> ": return " <> conjunction variant <> ";" ] | (tag, variant) <- tagged ]
      <> [ "    default: return 1;", "  }", "}" ]))
  , (aggregateNeed "compare" kind, (concat [snd (memberCompare member "" "") | member <- allMembers],
      [ "/* compareValues: the variants' names first, then the payload in order. */"
      , "static int " <> aggregateHelper "compare" kind <> "(pudu_box *a, pudu_box *b) {"
      , "  static const int rank[] = {" <> Text.intercalate ", " [number (nameRank variant) | (_, variant) <- tagged] <> "};"
      , "  int order;"
      , "  if (a->fields[0].scalar != b->fields[0].scalar) return rank[a->fields[0].scalar] < rank[b->fields[0].scalar] ? -1 : 1;"
      , "  switch (a->fields[0].scalar) {" ]
      <> concat [ ["    case " <> number tag <> ":"]
                  <> concat [ [ "      order = " <> fst (memberCompare member (payload "a" position member) (payload "b" position member)) <> ";"
                              , "      if (order != 0) return order;" ] | (position, member) <- members variant ]
                  <> ["      return 0;"]
                | (tag, variant) <- tagged ]
      <> [ "    default: (void)order; return 0;", "  }", "}" ]))
  , (aggregateNeed "comparable" kind, (concat [snd (memberComparable member "") | member <- allMembers],
      [ "static int " <> aggregateHelper "comparable" kind <> "(pudu_box *box) {"
      , "  switch (box->fields[0].scalar) {" ]
      <> [ "    case " <> number tag <> ": return " <> (case [held | held@(_, member) <- members variant, isAggregate member] of
             [] -> "1"
             present -> Text.intercalate " && " [fst (memberComparable member (payload "box" position member)) | (position, member) <- present]) <> ";"
         | (tag, variant) <- tagged ]
      <> [ "    default: return 1;", "  }", "}" ]))
  , (aggregateNeed "name" kind, (["text_literal"],
      [ "static pudu_text " <> aggregateHelper "name" kind <> "(pudu_box *box) {"
      , "  switch (box->fields[0].scalar) {" ]
      <> [ "    case " <> number tag <> ": return pudu_text_literal(" <> cString (coreVariantName variant) <> ", "
             <> number (cStringBytes (coreVariantName variant)) <> ");" | (tag, variant) <- tagged ]
      <> [ "    default: return pudu_text_literal(\"\", 0);", "  }", "}" ]))
  ] <>
  [ (aggregateNeed ("make" <> number tag) kind, (concat [snd (retained member "") | (_, member) <- members variant],
      [ "static pudu_box *" <> aggregateHelper ("make" <> number tag) kind <> "("
          <> (if null (members variant) then "void" else Text.intercalate ", " [cType member <> " m" <> number position | (position, member) <- members variant]) <> ") {"
      , "  pudu_box *box = pudu_box_new(" <> number (1 + length (members variant)) <> ");"
      , "  box->fields[0].scalar = " <> number tag <> ";" ]
      <> [ "  " <> payload "box" position member <> " = " <> fst (retained member ("m" <> number position)) <> ";" | (position, member) <- members variant ]
      <> [ "  return box;", "}" ]))
  | (tag, variant) <- tagged ]
 where
  tagged = zip [0 :: Int ..] variants
  nameRank variant = length [() | other <- variants, coreVariantName other < coreVariantName variant]
  members variant = zip [0 :: Int ..] (map snd (coreVariantFields variant))
  allMembers = concatMap (map snd . coreVariantFields) variants
  payload box position member = box <> "->fields[" <> number (position + 1) <> "]." <> cellName member
  conjunction variant = case members variant of
    [] -> "1"
    present -> Text.intercalate " && " [fst (memberEqual member (payload "a" position member) (payload "b" position member)) | (position, member) <- present]
  showVariant tag variant = case members variant of
    [] -> [ "    case " <> number tag <> ": return pudu_text_literal(" <> cString (coreVariantName variant) <> ", "
              <> number (cStringBytes (coreVariantName variant)) <> ");" ]
    present ->
      [ "    case " <> number tag <> ":" ]
      <> [ "      parts[" <> number position <> "] = " <> fst (memberRender member (payload "box" position member)) <> ";" | (position, member) <- present ]
      <> [ "      return pudu_text_join(" <> opening <> ", " <> labels <> ", parts, " <> number (length present) <> ", " <> closing <> ");" ]
     where
      -- renderValue: Name(a, b), or Name{x: a} for a record variant.
      (opening, labels, closing)
        | coreVariantRecord variant =
            ( cString (coreVariantName variant <> "{")
            , "(const char *const[]){" <> Text.intercalate ", " [cString (label <> ": ") | (label, _) <- coreVariantFields variant] <> "}"
            , "\"}\"" )
        | otherwise = (cString (coreVariantName variant <> "("), "NULL", "\")\"")
