{-| @Type.Check.Import.Module — installs body-free imported type interfaces -}
module Pudu.Type.Check.Import
  ( collectImportedDeclared
  , declareImportedTypes
  ) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Pudu.Type.Check.Install (installWanted, interfaceScope)
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , bindName
  , inheritRestrictions
  , lookupName
  )
import Pudu.Type.Interface.Graph
  ( ImportTypes (..)
  , consumerDefaults
  , consumerNames
  , consumerTraits
  , contributesTo
  , graphDeclared
  )
import Pudu.Type.Value (nominalKey)

{-| The declarations every imported interface collects to, overlaid with the
    consumer's spellings for what it imported.

    The collection itself is the graph's, formed once; see [[Type Interface Graph]]. -}
collectImportedDeclared :: ImportTypes -> Checker DeclaredTypes
collectImportedDeclared imported =
  pure collected
    { declaredNames = importedNames imported <> declaredNames collected
    , declaredAliases = aliases <> declaredAliases collected
    , declaredQualifiers = importedQualifiers imported <> declaredQualifiers collected
    }
 where
  collected = graphDeclared (importedGraph imported)
  aliases = Map.fromList
    [ (localName, target)
    | (localName, identity) <- Map.toList (importedNames imported)
    , Just target <- [Map.lookup (nominalKey identity) (declaredAliases collected)]
    ]

{-| Install what this consumer receives beyond what the graph installed for
    every module: the values it imported and the methods of the traits it can
    see, each formed under its declaring interface's names. -}
declareImportedTypes :: DeclaredTypes -> ImportTypes -> Checker ()
declareImportedTypes declared imported = do
  mapM_ installOne (filter (contributesTo imported) (importedInterfaces imported))
  mapM_ bindImportedValue (Map.toList (importedValues imported))
 where
  wantedValues = Set.fromList (Map.elems (importedValues imported))
  traits = consumerTraits imported
  defaults = consumerDefaults imported
  installOne value =
    installWanted
      (interfaceScope declared (consumerNames imported value) value)
      (importedTraits imported)
      wantedValues
      traits
      defaults
      value
  {-| The name this module reaches an imported value by, which an alias makes
      different from the name the value was declared under.

      The restrictions follow the binding for the same reason they follow the
      module qualifier: renaming a function at the import is a change of
      spelling, not a change of what it is allowed to do. -}
  bindImportedValue (localName, canonicalName) = do
    found <- lookupName canonicalName
    maybe (pure ()) (bindName localName) found
    inheritRestrictions canonicalName localName
