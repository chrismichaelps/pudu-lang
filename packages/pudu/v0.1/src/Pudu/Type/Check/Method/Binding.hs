{-| @Type.Check.Method.Binding — admits formed provider schemes without choosing between them. -}
module Pudu.Type.Check.Method.Binding
  ( MethodOrigin (..), MethodBinding (..), bindMethod, methodKey, implementationMethodKey ) where

import Control.Monad (when)
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker, bindName, bindImportedMethod, lookupName, isImportedMethod
  , methodProvider, markAmbiguousMethod, recordMethodProvider, recordDeclaredMethod, report )
import Pudu.Type.Value (NominalId, Scheme, Type (ErrorType), monotype, nominalKey, nominalName)

{-| Registration origin preserves interface collision checks and tooling ownership. -}
data MethodOrigin = InterfaceMethod | SourceMethod

{-| Formation owns the scheme; registration retains its declaration and provider identities. -}
data MethodBinding = MethodBinding
  { bindingOwner :: !NominalId
  , bindingProvider :: !(Maybe NominalId)
  , bindingName :: !(Located Text)
  , bindingSpan :: !Span
  , bindingScheme :: !Scheme
  }

bindMethod :: MethodOrigin -> MethodBinding -> Checker ()
bindMethod origin MethodBinding{bindingOwner, bindingProvider, bindingName, bindingSpan, bindingScheme} = do
  let name = locatedValue bindingName
      key = methodKey bindingOwner name
  existing <- lookupName key
  occupied <- case origin of
    InterfaceMethod -> pure (existing /= Nothing)
    SourceMethod -> isImportedMethod key
  previous <- methodProvider key
  let distinct = case (previous, bindingProvider) of
        (Just earlier, Just current) -> earlier /= current
        _ -> False
  if occupied && not distinct
    then do
      report "E3013" bindingSpan (name <> " is ambiguous for " <> nominalName bindingOwner)
        (Just "import only one providing trait or use a qualified call")
      bindName key (monotype ErrorType)
    else do
      mapM_ (\trait -> bindName (implementationMethodKey bindingOwner trait name) bindingScheme) bindingProvider
      when (distinct && existing /= Nothing) $
        markAmbiguousMethod key (maybe [] pure previous <> maybe [] pure bindingProvider)
      mapM_ (recordMethodProvider key) bindingProvider
      case origin of
        InterfaceMethod -> bindImportedMethod key bindingScheme
        SourceMethod -> do
          bindName key bindingScheme
          recordDeclaredMethod bindingOwner bindingName bindingScheme

{-| Explicit selection never reads the shared receiver ambiguity slot. -}
implementationMethodKey :: NominalId -> NominalId -> Text -> Text
implementationMethodKey owner trait member = nominalKey trait <> "::" <> methodKey owner member

methodKey :: NominalId -> Text -> Text
methodKey owner member = nominalKey owner <> "." <> member
