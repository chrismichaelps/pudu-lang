{-| Compare held values that use different native layouts. -}
module Pudu.Backend.Emit.CrossComparison
  ( Comparison (..), crossHelpers, differentLayoutCall, payloadRank ) where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Cell
  ( aggregateHelper, aggregateNeed, cellName, cType, isDynamicBox, mangle
  , memberCompare, memberEqual, number )
import Pudu.Backend.Emit.Support (isBigInteger, isWideInteger)
import Pudu.Core (CoreClosureInfo (..), CoreLayout (..), CoreType (..), CoreVariant (..))
import Pudu.Core.Closure (constructorIdentity)
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned))

data Comparison = Equality | Ordering

type Layouts = Map CoreType CoreLayout
type Pair = (CoreType, CoreType)
type Fragment = ([Text], [Pair], [Text])

operation :: Comparison -> Text
operation Equality = "equal"
operation Ordering = "compare"

crossName :: Comparison -> Pair -> Text
crossName comparison (left, right) =
  operation comparison <> "_" <> number (Text.length leftKey) <> "_" <> leftKey <> "_" <> mangle right
 where
  leftKey = mangle left

differentLayoutCall :: Comparison -> CoreType -> CoreType -> Text -> Text -> (Text, [Text])
differentLayoutCall comparison left right a b =
  ("pudu_cross_" <> name <> "(" <> a <> ", " <> b <> ")", ["agg_cross:" <> name])
 where
  name = crossName comparison (left, right)

crossHelpers :: Map Text Int -> Layouts -> [Pair] -> [(Text, ([Text], [Text]))]
crossHelpers identities layouts = visit Set.empty
 where
  visit _ [] = []
  visit seen (pair : rest)
    | Set.member pair seen = visit seen rest
    | otherwise =
        let generated = map (definition pair) [Equality, Ordering]
         in [(name, (needs, lines')) | (name, (needs, _, lines')) <- generated]
              <> visit (Set.insert pair seen) (concat [edges | (_, (_, edges, _)) <- generated] <> rest)
  definition pair@(left, right) comparison =
    let name = crossName comparison pair
        (needs, edges, body) = compareBody identities layouts comparison left right
        signature = "static int pudu_cross_" <> name <> "(" <> cType left <> " a, " <> cType right <> " b) {"
     in ("agg_cross:" <> name, (needs, edges, [signature, "  (void)a; (void)b;"] <> indent body <> ["}"]))

compareBody :: Map Text Int -> Layouts -> Comparison -> CoreType -> CoreType -> Fragment
compareBody identities layouts comparison left right
  | isDynamicBox left, Just (CoreSumLayout variants) <- Map.lookup left layouts =
      switch "a" variants (\_ payload -> single payload $ \kind -> finish kind right (cell "a" "1" kind) "b")
  | isDynamicBox right, Just (CoreSumLayout variants) <- Map.lookup right layouts =
      switch "b" variants (\_ payload -> single payload $ \kind -> finish left kind "a" (cell "b" "1" kind))
  | otherwise = case (left, right) of
      (CoreTupleType a, CoreTupleType b) -> fields 0 (unlabelled a) (unlabelled b)
      (CoreRecordType ownerA _, CoreRecordType ownerB _)
        | ownerA == ownerB
        , Just (CoreRecordLayout a) <- Map.lookup left layouts
        , Just (CoreRecordLayout b) <- Map.lookup right layouts -> fields 0 a b
        | otherwise -> constant (compare ownerA ownerB)
      (CoreSumType ownerA _, CoreSumType ownerB _)
        | Just (CoreSumLayout a) <- Map.lookup left layouts
        , Just (CoreSumLayout b) <- Map.lookup right layouts ->
            switch "a" a $ \va afields ->
              switch "b" b $ \vb bfields ->
                case compare (coreVariantRecord va, ownerA, coreVariantName va) (coreVariantRecord vb, ownerB, coreVariantName vb) of
                  EQ -> fields 1 afields bfields
                  order -> constant order
      (CoreArrayType a, CoreArrayType b) ->
        sequences ["array"] ["pudu_items *left = a->fields[0].items, *right = b->fields[0].items;"]
          "left->length" "right->length" [] [(a,b,arrayCell "left" a,arrayCell "right" b)]
      (CoreSetType a, CoreSetType b) -> tree [(a,b,"key")]
      (CoreMapType ak av, CoreMapType bk bv) -> tree [(ak,bk,"key"),(av,bv,"value")]
      (CoreStoreType a, CoreStoreType b) ->
        let key = CoreIntegerType PlatformSigned
         in tree [(key,key,"key"),(a,b,"value")]
      (CoreFunctionType{}, CoreFunctionType{})
        | Just (CoreClosureLayout a) <- Map.lookup left layouts
        , Just (CoreClosureLayout b) <- Map.lookup right layouts -> case comparison of
            Equality -> closures a b
            Ordering -> mconcat
              [ whenConstructor "a" indexA (whenConstructor "b" indexB (constant (compare keyA keyB)))
              | (indexA, keyA) <- constructors a, (indexB, keyB) <- constructors b ] <> ranked
      (CoreFunctionType{}, CoreSumType owner _)
        | Just (CoreClosureLayout a) <- Map.lookup left layouts
        , Just (CoreSumLayout b) <- Map.lookup right layouts ->
            constructorSum "a" "b" id a owner b
      (CoreSumType owner _, CoreFunctionType{})
        | Just (CoreSumLayout a) <- Map.lookup left layouts
        , Just (CoreClosureLayout b) <- Map.lookup right layouts ->
            constructorSum "b" "a" reverseOrder b owner a
      _ -> case comparison of
        Equality -> code ["return 0;"]
        Ordering -> case numericPayloadOrder left right "a" "b" of
          Just (needs, body) -> (needs, [], ["int order; (void)order;"] <> body)
          Nothing -> ranked
 where
  ranked =
    let (rankA, needsA) = payloadRank left "a"
        (rankB, needsB) = payloadRank right "b"
     in (needsA <> needsB, [], ["return " <> rankOrder rankA rankB <> ";"])
  finish a b av bv =
    let (expression, needs, pairs) = member comparison a b av bv
     in (needs, pairs, ["return " <> expression <> ";"])
  single [(_, kind)] use = use kind
  single _ _ = invalid
  invalid = code ["return 0;"]
  constant order = code ["return " <> case comparison of
      Equality -> (if order == EQ then "1;" else "0;")
      Ordering -> (case order of { LT -> "-1;"; EQ -> "0;"; GT -> "1;" })]
  constructors entries =
    [ (index, identity)
    | (key, info) <- entries, Just index <- [Map.lookup key identities], Just identity <- [constructorIdentity info] ]
  whenConstructor box index body =
    code ["if (" <> box <> "->fields[0].scalar == " <> number index <> ") {"]
      <> indented body <> code ["}"]
  constructorSum constructorBox sumBox order closures' owner variants =
    mconcat
      [ whenConstructor constructorBox index $ switch sumBox variants $ \variant members ->
          constant (order (compare (False, declared, tag, 0 :: Int)
            (coreVariantRecord variant, owner, coreVariantName variant, length members)))
      | (index, (declared, tag)) <- constructors closures' ]
    <> case comparison of
      Equality -> invalid
      Ordering -> ranked
  reverseOrder LT = GT
  reverseOrder EQ = EQ
  reverseOrder GT = LT
  unlabelled = map (("",))
  fields first a b = go first a b
   where
    go index ((labelA, kindA) : as) ((labelB, kindB) : bs) =
      case compare labelA labelB of
        EQ -> guardPair kindA kindB (cell "a" (number index) kindA) (cell "b" (number index) kindB) <> go (index + 1) as bs
        order -> constant order
    go _ as bs = constant (compare (length as) (length bs))
  guardPair a b av bv =
    let (expression, needs, pairs) = member comparison a b av bv
     in (needs, pairs, case comparison of
          Equality -> ["if (!(" <> expression <> ")) return 0;"]
          Ordering -> ["{ int order = " <> expression <> "; if (order != 0) return order; }"])
  switch box variants use =
    code ["switch (" <> cell box "0" CoreBoolType <> ") {"]
    <> mconcat
      [ code ["case " <> number tag <> ": {"]
          <> indented (use variant (coreVariantFields variant)) <> code ["}"]
      | (tag, variant) <- zip [0 ..] variants ]
    <> code ["default: return 0;", "}"]
  closures a b = mconcat
    [ code ["if (a->fields[0].scalar == " <> number indexA <> " && b->fields[0].scalar == " <> number indexB <> ") {"]
        <> indented (fields 1 (unlabelled (identityCaptures infoA)) (unlabelled (identityCaptures infoB)))
        <> code ["}"]
    | (keyA, infoA) <- a, Just indexA <- [Map.lookup keyA identities]
    , (keyB, infoB) <- b, Just indexB <- [Map.lookup keyB identities]
    , closureSite infoA == closureSite infoB, closureDisplayName infoA == closureDisplayName infoB ]
    <> invalid
  identityCaptures info
    | "<task " `Text.isPrefixOf` closureDisplayName info = closureCaptures info
    | Just _ <- closureMethod info = take 1 (closureCaptures info)
    | otherwise = []
  tree fields' = sequences ["tree_walk"]
    [ "size_t left_count = pudu_tree_size(a->fields[0].tree);"
    , "size_t right_count = pudu_tree_size(b->fields[0].tree);" ]
    "left_count" "right_count"
    [ "pudu_tree_node **left = pudu_tree_nodes(a->fields[0].tree);"
    , "pudu_tree_node **right = pudu_tree_nodes(b->fields[0].tree);" ]
    [(a,b,nodeCell "left" field a,nodeCell "right" field b) | (a,b,field) <- fields']
  sequences base declarations leftCount rightCount allocate comparisons =
    let calls = [member comparison a b av bv | (a,b,av,bv) <- comparisons]
        cleanup = if null allocate then [] else ["free(left);", "free(right);"]
        (prelude, condition, loopBody, result) = case comparison of
          Equality ->
            ( ["if (" <> leftCount <> " != " <> rightCount <> ") return 0;", "int same = 1;"]
            , leftCount <> " && same"
            , ["same = " <> Text.intercalate " && " ["(" <> expression <> ")" | (expression, _, _) <- calls] <> ";"]
            , ["return same;"] )
          Ordering ->
            ( ["size_t shorter = " <> leftCount <> " < " <> rightCount <> " ? " <> leftCount <> " : " <> rightCount <> ";", "int order = 0;"]
            , "shorter && order == 0"
            , ["if (order == 0) order = " <> expression <> ";" | (expression, _, _) <- calls]
            , ["if (order != 0) return order;", "return " <> rankOrder leftCount rightCount <> ";"] )
     in (base <> concat [needs | (_, needs, _) <- calls], concat [pairs | (_, _, pairs) <- calls],
          declarations <> prelude <> allocate <> ["for (size_t i = 0; i < " <> condition <> "; ++i) {"]
          <> indent loopBody <> ["}"] <> cleanup <> result)

member :: Comparison -> CoreType -> CoreType -> Text -> Text -> (Text, [Text], [Pair])
member comparison left right a b
  | left == right =
      let (expression, needs) = case comparison of
            Equality -> memberEqual left a b
            Ordering -> memberCompare left a b
       in (expression, needs, [])
  | otherwise =
      let (expression, needs) = differentLayoutCall comparison left right a b
       in (expression, needs, [(left, right)])

cell :: Text -> Text -> CoreType -> Text
cell box index kind = box <> "->fields[" <> index <> "]." <> cellName kind

arrayCell :: Text -> CoreType -> Text
arrayCell items kind = items <> "->cells[i]." <> cellName kind

nodeCell :: Text -> Text -> CoreType -> Text
nodeCell nodes field kind = nodes <> "[i]->" <> field <> "." <> cellName kind

rankOrder :: Text -> Text -> Text
rankOrder a b = "(" <> a <> " > " <> b <> ") - (" <> a <> " < " <> b <> ")"

code :: [Text] -> Fragment
code lines' = ([], [], lines')

indent :: [Text] -> [Text]
indent = map ("  " <>)

indented :: Fragment -> Fragment
indented (needs, pairs, lines') = (needs, pairs, indent lines')

numericPayloadOrder :: CoreType -> CoreType -> Text -> Text -> Maybe ([Text], [Text])
numericPayloadOrder aKind bKind a b = case (aKind, bKind) of
  (CoreIntegerType left, CoreIntegerType right)
    | family left == family right ->
        let (compared, needs) = memberCompare aKind a b
         in Just (needs, ["return " <> compared <> ";"])
    | otherwise ->
        let (leftCall, leftNeed) = toBig left a
            (rightCall, rightNeed) = toBig right b
         in Just ([leftNeed, rightNeed, "big_compare", "big_release"],
              [ "pudu_big *left = " <> leftCall <> ";"
              , "pudu_big *right = " <> rightCall <> ";"
              , "order = pudu_big_compare(left, right);"
              , "pudu_big_release(left);"
              , "pudu_big_release(right);"
              , "return order;" ])
  (CoreFloatType _, CoreFloatType _) ->
    Just (["float_order"], ["return pudu_float_order(" <> a <> ", " <> b <> ");"])
  (CoreIntegerType integer, CoreFloatType _) -> Just (mixed integer a b False)
  (CoreFloatType _, CoreIntegerType integer) -> Just (mixed integer b a True)
  _ -> Nothing
 where
  family integer
    | isBigInteger integer = (2 :: Int)
    | isWideInteger integer = 1
    | otherwise = 0
  toBig integer value = let helper = case family integer of
                                  2 -> "big_retain"
                                  1 -> "wide_to_big"
                                  _ -> "int_to_big"
                         in ("pudu_" <> helper <> "(" <> value <> ")", helper)
  mixed integer value floating reversed =
    let (converted, needs) = toBig integer value
        left = if reversed then floating else "real"
        right = if reversed then "real" else floating
     in ( [needs, "dec_make", "dec_to_float", "dec_release", "float_order"]
        , [ "pudu_dec *exact = pudu_dec_make(" <> converted <> ", 0);"
          , "uint64_t real = pudu_dec_to_float(exact);"
          , "pudu_dec_release(exact);"
          , "return pudu_float_order(" <> left <> ", " <> right <> ");" ])

{-| The interpreter's shape order for values held in a dynamic box. A sum's
    active alternative decides whether it has a positional or named payload. -}
payloadRank :: CoreType -> Text -> (Text, [Text])
payloadRank kind value = case kind of
  CoreSumType{} -> (aggregateHelper "rank" kind <> "(" <> value <> ")", [aggregateNeed "rank" kind])
  CoreFunctionType{} -> (aggregateHelper "rank" kind <> "(" <> value <> ")", [aggregateNeed "rank" kind])
  _ -> (number (rankOf kind), [])
 where
  rankOf CoreUnitType = 0
  rankOf CoreNeverType = 1
  rankOf CoreBoolType = 2
  rankOf CoreIntegerType{} = 3
  rankOf CoreFloatType{} = 3
  rankOf CoreCharType = 4
  rankOf CoreTextType = 5
  rankOf CoreTupleType{} = 6
  rankOf CoreArrayType{} = 7
  rankOf CoreSumType{} = 8
  rankOf CoreRecordType{} = 9
  rankOf CoreFunctionType{} = 10
  rankOf CoreSetType{} = 16
  rankOf CoreMapType{} = 17
  rankOf CoreDecimalType = 18
  rankOf CoreBytesType = 21
  rankOf CoreStoreType{} = 23
  rankOf CoreHandleType{} = 26
  rankOf CoreRangeType = 27
  rankOf CoreCallbackType{} = 33
