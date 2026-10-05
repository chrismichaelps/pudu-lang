{-| @Derive.Syntax — shared bounded identities and source-independent structure. -}
module Pudu.Derive.Syntax
  ( sameTypeShape, patternNames, instantiatePattern, retag, isStaticValue ) where

import Data.Text (Text)
import Pudu.Derive.State (Residual, generated, withinDepth)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Frontend.Syntax.Tree
  ( ArrayRest (..), Capability, Expression (..), FieldPattern (..), Pattern (..)
  , TypeSyntax (..) )

retag :: Located a -> Residual (Located a)
retag (Located at value) = generated at value

sameTypeShape :: TypeSyntax -> TypeSyntax -> Bool
sameTypeShape left right = typeShape left == typeShape right

isStaticValue :: Located Expression -> Bool
isStaticValue (Located _ value) = case value of
  LiteralExpression _ -> True
  TupleExpression members -> all isStaticValue members
  ArrayExpression members -> all isStaticValue members
  UnaryExpression operator held -> operator `elem` ["-", "+", "!"] && isStaticValue held
  _ -> False

data TypeShape
  = NamedShape !ModuleName ![TypeShape]
  | DynamicShape !ModuleName
  | BorrowedShape !Bool !TypeShape
  | TupleShape ![TypeShape]
  | FunctionShape !Bool ![TypeShape] !TypeShape
  | UnsafeShape ![Capability] !TypeShape
  | UnitShape
  | InvalidShape
  deriving stock (Eq)

-- Compare nominal spellings and full structure, never authored locations.
typeShape :: TypeSyntax -> TypeShape
typeShape written = case written of
  NamedType path arguments -> NamedShape path (map recurse arguments)
  DynamicType path -> DynamicShape path
  ReferenceType mutable target -> BorrowedShape mutable (recurse target)
  TupleType members -> TupleShape (map recurse members)
  FunctionType async inputs result -> FunctionShape async (map recurse inputs) (recurse result)
  UnsafeType capabilities target -> UnsafeShape (map locatedValue capabilities) (recurse target)
  UnitType -> UnitShape
  InvalidType -> InvalidShape
 where
  recurse = typeShape . locatedValue

patternNames :: Located Pattern -> [Text]
patternNames (Located _ value) = case value of
  BindingPattern name -> [locatedValue name]
  TuplePattern members -> concatMap patternNames members
  ArrayPattern prefix rest suffix -> concatMap patternNames (prefix <> suffix) <> case rest of
    Just (BoundRest name) -> [locatedValue name]
    _ -> []
  ConstructorPattern _ members -> concatMap patternNames members
  RecordPattern _ fields _ -> concatMap names fields
  AlternativePattern alternatives -> concatMap patternNames alternatives
  _ -> []
 where
  names (Located _ field) = maybe [locatedValue (fieldPatternName field)] patternNames (fieldPatternValue field)

instantiatePattern :: Int -> Located Pattern -> Residual (Located Pattern)
instantiatePattern depth (Located at value) = do
  withinDepth depth at
  rewritten <- case value of
    BindingPattern name -> BindingPattern <$> retag name
    TuplePattern members -> TuplePattern <$> mapM recurse members
    ArrayPattern prefix rest suffix -> ArrayPattern <$> mapM recurse prefix <*> mapM arrayRest rest <*> mapM recurse suffix
    ConstructorPattern path members -> ConstructorPattern path <$> mapM recurse members
    RecordPattern path fields rest -> RecordPattern path <$> mapM fieldPattern fields <*> pure rest
    AlternativePattern alternatives -> AlternativePattern <$> mapM recurse alternatives
    other -> pure other
  generated at rewritten
 where
  recurse = instantiatePattern (depth + 1)
  arrayRest rest = case rest of
    BoundRest name -> BoundRest <$> retag name
    IgnoredRest held -> IgnoredRest . locatedSpan <$> generated held ()
  fieldPattern (Located fieldAt field) = do
    name <- retag (fieldPatternName field)
    held <- mapM recurse (fieldPatternValue field)
    generated fieldAt (FieldPattern name held)
