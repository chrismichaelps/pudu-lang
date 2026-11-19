{-| @Type.Check.Static — functions that may read nothing but their arguments.

    A value of a sum type declared `#[static_function]` holds functions whose
    result may be reused while their arguments are unchanged. A lambda or a
    local binding can read surrounding values that never reach those
    arguments, so every function given to such a constructor must name a
    module-level function. The rule is keyed by the type's nominal identity,
    so it holds through any import alias. -}
module Pudu.Type.Check.Static
  ( checkStaticArguments
  ) where

import Control.Monad (forM_, unless)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Maybe (isNothing)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Expression (..))
import Pudu.Type.Env (Checker, DeclaredTypes (..), lookupLocalName, report)
import Pudu.Type.Unify (zonk)
import Pudu.Type.Value (Type (..))

{-| Refuses each argument of a constructor of a `#[static_function]` type that
    is not a module-level function's name. `result` is the call's type, which
    names the type the constructor belongs to. -}
checkStaticArguments :: DeclaredTypes -> Located Expression -> Type -> [Located Expression] -> Checker ()
checkStaticArguments declared callee result arguments = do
  resolved <- zonk result
  case resolved of
    NominalType owner _
      | Set.member owner (declaredStaticFunctions declared)
      , Just label <- calleeLabel (locatedValue callee)
      , label `elem` Map.findWithDefault [] owner (declaredOwners declared) ->
          forM_ arguments $ \argument -> do
            named <- namesModuleFunction (locatedValue argument)
            unless named $
              report "E3103" (locatedSpan argument)
                "this argument must name a module-level function"
                (Just "a lambda or a local can read values its arguments do not carry; declare the function at module level and pass its name")
    _ -> pure ()

calleeLabel :: Expression -> Maybe Text
calleeLabel expression = case expression of
  NameExpression names -> Just (NonEmpty.last names)
  MemberExpression _ (Located _ label) -> Just label
  _ -> Nothing

-- A name whose first segment is not a local binding: a function of this
-- module, or one reached through an import.
namesModuleFunction :: Expression -> Checker Bool
namesModuleFunction expression = case expression of
  NameExpression (first :| _) -> isNothing <$> lookupLocalName first
  MemberExpression target _ -> namesModuleFunction (locatedValue target)
  _ -> pure False
