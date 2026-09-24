{-# OPTIONS_GHC -Wno-orphans #-}
{-| @Syntax.Stored.Module — the stored form of every syntax tree node

    Kept apart from the tree so the tree's module holds its shapes alone. The
    instances live here rather than beside the class because the class knows
    nothing of syntax; every module that stores or reads a tree imports this
    one, and a missing import is a compile error rather than a silent change. -}
module Pudu.Frontend.Syntax.Stored () where

import Pudu.Cache.Persist (Persist (..), persistDeferred, restoreDeferred)
import Pudu.Frontend.Syntax.Tree
import Pudu.IntegerLiteral (IntegerKind)

{-| Each declaration is stored as a block of its own, so reading a stored module
    reads its name and imports and leaves every declaration unread until
    something looks at it. A list holds its elements lazily, which is what
    lets them wait. -}
instance Persist Module where
  persist source value =
    persist source (moduleSpan value)
      <> persist source (moduleName value)
      <> persist source (moduleImports value)
      <> persist source (length (moduleDeclarations value))
      <> foldMap (persistDeferred source) (moduleDeclarations value)
  restore = do
    spanValue <- restore
    name <- restore
    imports <- restore
    count <- restore
    declarations <- deferredList (count :: Int)
    pure Module
      { moduleSpan = spanValue
      , moduleName = name
      , moduleImports = imports
      , moduleDeclarations = declarations
      }
   where
    deferredList remaining
      | remaining <= 0 = pure []
      | otherwise = (:) <$> restoreDeferred <*> deferredList (remaining - 1)
instance Persist Import
instance Persist Visibility
instance Persist Capability
instance Persist BindingKind
instance Persist Declaration
{-| A function's body is stored as a block of its own and read when first
    reached, so loading a stored module does not read the bodies nothing calls.
    `Just` holds its contents lazily, which is what lets the body wait. -}
instance Persist Function where
  persist source value =
    persist source (functionVisibility value)
      <> persist source (functionAsync value)
      <> persist source (functionUnsafe value)
      <> persist source (functionComptime value)
      <> persist source (functionName value)
      <> persist source (functionTypeParams value)
      <> persist source (functionParameters value)
      <> persist source (functionReturn value)
      <> persist source (functionConstraints value)
      <> maybe (persist source False) (\body -> persist source True <> persistDeferred source body) (functionBody value)
  restore = do
    visibility <- restore
    asynchronous <- restore
    unsafeCapabilities <- restore
    comptime <- restore
    name <- restore
    typeParams <- restore
    parameters <- restore
    returned <- restore
    constraints <- restore
    hasBody <- restore
    body <- if hasBody then Just <$> restoreDeferred else pure Nothing
    pure Function
      { functionVisibility = visibility
      , functionAsync = asynchronous
      , functionUnsafe = unsafeCapabilities
      , functionComptime = comptime
      , functionName = name
      , functionTypeParams = typeParams
      , functionParameters = parameters
      , functionReturn = returned
      , functionConstraints = constraints
      , functionBody = body
      }
instance Persist TypeParam
instance Persist Constraint
instance Persist TypeDeclarationValue
instance Persist TypeDefinition
instance Persist FieldDeclaration
instance Persist Variant
instance Persist VariantPayload
instance Persist Trait
instance Persist Impl
instance Persist Macro
instance Persist MacroParam
instance Persist MacroKind
instance Persist Parameter
instance Persist TypeSyntax
instance Persist FunctionBody
instance Persist Block
instance Persist Statement
instance Persist IntegerKind
instance Persist Literal
instance Persist Pattern
instance Persist ArrayRest
instance Persist FieldPattern
instance Persist Foreign
instance Persist ForeignFunction
instance Persist ForeignParameter
instance Persist FieldInit
instance Persist MatchArm
instance Persist Expression
