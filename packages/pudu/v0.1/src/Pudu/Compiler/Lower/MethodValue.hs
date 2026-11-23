{-| @Pudu.Compiler.Lower.MethodValue — methods taken as values, like
    `text.length`, `items.push` or a trait's `bot.label`. The receiver runs once, when the value is
    made, and is kept as the closure's capture. Calling the value runs the
    method on it through the same lowering a written call gets. -}
module Pudu.Compiler.Lower.MethodValue
  ( lowerMethodValue, lowerTraitMethodValue, lowerDynamicTextCall, registerMethodValue
  , boundMemberFact, declaredMemberType ) where

import Control.Applicative ((<|>))
import qualified Data.Set as Set
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.State
  ( CallableSource (..), CallableTemplate (..), Instance (..), LowerContext (..), LowerState (..), MutableSite (MutableParameterSite, MutableReceiverSite)
  , bindLocal, bindMutable, halt, lookupLocal, refuse, refused, startFunction )
import Pudu.Compiler.Lower.Control (blockType)
import Pudu.Compiler.Lower.Dynamic (hasRuntimeChoice, joinRuntimeArms, mapRuntimeChoice, missingRuntimeMember, preserveRuntimeResult, projectRuntimeValue, runtimeCarriers, runtimeResultType, settledMutableLayout)
import Pudu.Compiler.Lower.Generic (matchType)
import Pudu.Compiler.Lower.Loan (closeLoaned, withLoanedParameters)
import Pudu.Compiler.Lower.Place (holdPlace, readHeldAtKeys, storeHeld)
import Pudu.Compiler.Lower.Text (lowerTextMethod)
import Pudu.Compiler.Lower.Types (formedCoreTypeIn, isDynamic, loanedInputs, ownerKeyOf, recordFields, selectedMember, sumVariants, typeFactAt, typeForSpan, unformed, withFacts)
import Pudu.Core
import Pudu.Core.Closure (textMethodPrefix)
import Pudu.Eval.Operator.Access (builtinMethodNamesFor)
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Data.Maybe (fromMaybe, isJust, isNothing)
import Pudu.Source (Span (..), offsetFromInt, zeroOffset)
import Pudu.Type.Substitute (substituteRigid)
import Pudu.Type.Value (Required (Required), Scheme (schemeType), Type (FunctionTypeRequiring, FunctionTypeValue, NominalType, ReferenceTypeValue), requiredCount, stringType)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

declaredMemberType :: LowerContext -> CoreType -> Text -> Maybe Type
declaredMemberType context kind written = do
  owner <- ownerKeyOf kind
  let (provider, plain) = selectedMember written
      qualified = provider >>= \trait -> Map.lookup (trait, owner, plain) (contextTraitMethods context)
  key <- qualified <|> Map.lookup (owner, plain) (contextMethods context)
  schemeType . instanceScheme <$> Map.lookup key (contextInstances context)

boundMemberFact :: CoreType -> Type -> Maybe Type
boundMemberFact kind (FunctionTypeRequiring asynchronous (self : inputs) required result) = do
  bindings <- matchType self (unformed kind) Map.empty
  let substitute = substituteRigid (Map.toList bindings)
  pure (FunctionTypeRequiring asynchronous (map substitute inputs)
    (Required (max 0 (requiredCount required - 1))) (substitute result))
boundMemberFact _ _ = Nothing

intrinsicTextFact :: CoreType -> Type
intrinsicTextFact CoreBytesType = FunctionTypeValue False [] (NominalType "Option" [stringType])
intrinsicTextFact _ = FunctionTypeValue False [] stringType

lowerTraitMethodValue :: LowerExpression -> LowerState -> Span -> Text -> Text -> Lowered
lowerTraitMethodValue lower state at provider member =
  let receiver = Located at (NameExpression ("::trait-method::" :| [provider]))
   in maybe (refused (refuse at "a trait method value without a settled native function type" state))
        id (lowerMethodValue lower state at receiver member)

lowerDynamicTextCall :: LowerExpression -> LowerState -> Span -> Span -> Located Expression -> CoreType -> Lowered
lowerDynamicTextCall lower state at callee receiver kind =
  lowerDynamicText lower state at receiver kind CoreTextType True (textCall callee)

textCall :: Span -> Located Expression -> Expression
textCall callee held = CallExpression (Located callee (MemberExpression held (Located callee "toText"))) []

{-| Select the held receiver before lowering its member. A member read
    therefore captures the payload at selection time and uses the ordinary
    closure identity and display. -}
lowerDynamicText :: LowerExpression -> LowerState -> Span -> Located Expression -> CoreType -> CoreType
  -> Bool -> (Located Expression -> Expression) -> Lowered
lowerDynamicText lower state at receiver kind result direct build =
  case sumVariants (contextTypes (lowerContext state)) kind of
    Nothing -> halt at "text conversion without a settled dynamic layout" state
    Just variants -> case receive variants of
      (after, Nothing) -> refused after
      (after, Just (prelude, core, place))
        | coreExpressionType core == CoreNeverType || blockType prelude Nothing == CoreNeverType ->
            answer after CoreNeverType (CoreBlockValue (CoreBlock prelude (Just core)))
        | otherwise -> emit after prelude core place [] variants
 where
  heldAt = at{spanStart = offset, spanEnd = offset}
  offset = fromMaybe zeroOffset (offsetFromInt maxBound)
  heldName = "$textReceiver"
  answer current kind' shape = (current, Just (CoreExpression at kind' shape, kind'))
  declaredMethod payload = declaredMemberType (lowerContext state) payload "toText"
  mutating payload = direct && maybe False (elem 0 . loanedInputs) (declaredMethod payload)
  selectedFact types payload
    | Just field <- recordFields types payload >>= lookup "toText" = Just (unformed field)
    | payload `elem` [CoreBytesType, CoreCharType] = Just (intrinsicTextFact payload)
    | otherwise = declaredMethod payload >>= boundMemberFact payload
  receive variants
    | any mutating [payload | variant <- variants, (_, payload) <- coreVariantFields variant]
    , Just (after, held) <- holdPlace lower state (locatedSpan receiver) receiver =
        (after, (\(prelude, place) -> (prelude, readHeldAtKeys (contextTypes (lowerContext after)) place, Just place)) <$> held)
    | otherwise = fmap (fmap (\(core, _) -> ([], core, Nothing))) (lower state receiver)
  emit current prelude core _ arms [] =
    let joined = preserveRuntimeResult result (joinRuntimeArms at result core (reverse arms))
     in answer current (coreExpressionType joined) (CoreBlockValue (CoreBlock prelude (Just joined)))
  emit current prelude core place arms (variant : rest) = case coreVariantFields variant of
    [(_, payload)] ->
      let types = contextTypes (lowerContext current)
          (bound, local) = bindLocal current{lowerScopes = [] : lowerScopes current} heldName payload
          facts = (heldAt, unformed payload) : [(at, fact) | not direct, Just fact <- [selectedFact types payload]]
          prepared = bound{lowerContext = (lowerContext bound){contextTypes = withFacts facts types}}
          target = Located heldAt (NameExpression (heldName :| []))
          (after, lowered) = lower prepared (Located at (build target))
          pattern' = CoreVariantPattern (coreVariantName variant) [CoreBindPattern local]
          close next = next{lowerContext = (lowerContext next){contextTypes = types}, lowerScopes = drop 1 (lowerScopes next)}
          writeBack body = case place of
            Just found | mutating payload, coreExpressionType body /= CoreNeverType ->
              let answered = coreExpressionType body
                  (ready, answerLocal) = bindLocal after "" answered
                  reading = CoreExpression at payload (CoreReadLocal local)
                  updated = CoreExpression at kind (CoreConstruct (coreVariantName variant) [("0", reading)])
                  statements = [CoreStatement at (CoreDeclare answerLocal body), storeHeld types at found updated]
               in (ready, CoreExpression at answered (CoreBlockValue (CoreBlock statements
                    (Just (CoreExpression at answered (CoreReadLocal answerLocal))))))
            _ -> (after, body)
       in case lowered of
            Just (body, _) ->
              let (ready, selected) = writeBack body
               in emit (close ready) prelude core place (CoreArm at pattern' Nothing selected : arms) rest
            Nothing -> refused (close after)
    _ -> halt at "text conversion on a dynamic variant without one payload" current

{-| Nothing unless checking typed the member as a function and it is a
    method: of a built-in value, or of a declared type that has no field of
    that name (a field holding a function is read, not bound). `Bot.label`,
    with a type for a receiver, is the method itself, taking `self` first. -}
lowerMethodValue :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> Maybe Lowered
lowerMethodValue lower state at receiver member = case (receiverFact, typeForSpan types at, typeFactAt types at) of
  (Just receiverType, Just kind@(CoreFunctionType inputs _), Just fact@(FunctionTypeRequiring _ inputFacts _ _))
    | member == "toText", isDynamic receiverType ->
        Just (lowerDynamicText lower state at receiver receiverType kind False
          (\held -> MemberExpression held (Located at member)))
    | builtIn receiverType || declared receiverType || textual receiverType, length inputs == length inputFacts -> Just $ case lower state receiver of
        (after, Nothing) -> refused after
        (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
        (after, Just (core, _)) ->
          let preserve (value, _) =
                let carried = preserveRuntimeResult kind value
                 in (carried, coreExpressionType carried)
           in fmap (fmap preserve) (bindReceiver receiverType kind fact after core)
  (Nothing, Just kind@(CoreFunctionType inputs@(self : _) _), Just fact@(FunctionTypeRequiring _ inputFacts _ _))
    | Just owner <- unboundOwner self
    , length inputs == length inputFacts ->
        let key = (if traitValue then "$trait-method:" else "$method:") <> owner <> "." <> member <> ":" <> Text.pack (show kind)
         in Just (closure state key Nothing kind fact [])
  _ -> Nothing
 where
  types = contextTypes (lowerContext state)
  receiverFact = if traitValue then Nothing else typeForSpan types (locatedSpan receiver)
  unboundOwner self = case locatedValue receiver of
    NameExpression ("::trait-method::" :| [provider]) -> Just provider
    NameExpression (owner :| [])
      | Nothing <- lookupLocal state owner, declared self
      , ownerKeyOf self == Just owner || fmap displayName (ownerKeyOf self) == Just owner ->
          Just owner
    _ -> Nothing
  traitValue = case locatedValue receiver of
    NameExpression ("::trait-method::" :| [_]) -> True
    _ -> False
  -- The member's own name, without the provider checking selected.
  (provider, plain) = selectedMember member
  builtIn kind = case kind of
    CoreTextType -> True
    CoreArrayType _ -> True
    CoreMapType _ _ -> True
    CoreSetType _ -> True
    CoreStoreType _ -> True
    CoreRangeType -> True
    CoreCharType -> True
    CoreBytesType -> True
    _ -> False
  -- `toText` on a type that declares none renders the receiver; the
  -- interpreter names that value a text method.
  textual kind = plain == "toText"
    && isNothing (recordFields types kind >>= lookup plain)
    && isNothing (declaredMemberType (lowerContext state) kind member)
  declared kind = case kind of
    CoreRecordType _ _ -> isNothing (recordFields types kind >>= lookup plain)
    CoreSumType _ _ -> True
    _ -> isJust (declaredMemberType (lowerContext state) kind member)
  bindReceiver receiverType kind fact current core
    | Just selected <- mapRuntimeChoice current at kind core
        (\ready held -> fmap (fmap fst) (bindReceiver receiverType kind fact ready held)) = selected
    | unformed actual == unformed receiverType = bind kind fact ordinaryText
    | Just field <- recordFields currentTypes actual >>= lookup plain =
        (current, Just (CoreExpression at field (CoreField plain core), field))
    | plain == "toText", actual `elem` [CoreCharType, CoreBytesType] =
        bindText
    | intrinsic = bind kind fact False
    | Just scheme <- declaredMemberType context actual member =
        case boundMemberFact actual scheme >>= \selected -> (,) selected <$> formedCoreTypeIn currentTypes selected of
          Just (selectedFact, selectedKind) -> bind selectedKind selectedFact False
          Nothing -> halt at ("the selected method value '" <> plain <> "' without a settled native signature") current
    | plain == "toText" = bindText
    | otherwise = (current, Just (missingRuntimeMember at plain core, CoreNeverType))
   where
    context = lowerContext current
    currentTypes = contextTypes context
    actual = coreExpressionType core
    intrinsic = isNothing provider && plain /= "toText"
      && maybe False (elem plain . builtinMethodNamesFor) (ownerKeyOf actual)
    ordinaryText = plain == "toText" && actual `notElem` [CoreCharType, CoreBytesType]
      && isNothing (declaredMemberType context actual member)
    bindText =
      let selected = intrinsicTextFact actual
       in case formedCoreTypeIn currentTypes selected of
            Just selectedKind -> bind selectedKind selected ordinaryText
            Nothing -> halt at "a text method value without a native signature" current
    bind selectedKind selectedFact asText =
      let key = (if asText then textMethodPrefix else "$method:") <> member <> ":" <> Text.pack (show actual) <> ":" <> Text.pack (show selectedKind)
       in closure current key (Just actual) selectedKind selectedFact [core]
  closure current key bound kind fact captures = case registerMethodValue lower current at receiver member key bound kind fact of
    (after, Just actual) -> (after, Just (CoreExpression at actual (CoreClosure key captures), actual))
    (after, Nothing) -> refused after

{-| Register the checked call over an already retained receiver and native parameters. -}
registerMethodValue :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> Text
  -> Maybe CoreType -> CoreType -> Type -> (LowerState, Maybe CoreType)
registerMethodValue lower current at receiver member key bound solved@(CoreFunctionType requested checkedResult)
    whole@(FunctionTypeRequiring asynchronous inputFacts _ resultFact)
  | Map.member key (contextClosures initial) || Set.member key (contextActiveCallables initial) =
      (current, Just kind)
  | otherwise =
      let env = CoreLocal 0 "" kind
          offset = maybe 0 (const 1) bound
          parameters = [CoreParameter (CoreLocal (index - 1 + offset) (argumentName index) input) at | (index, input) <- zip [1 ..] inputs]
          hidden = [CoreParameter env at | Just _ <- [bound]]
          active = initial{contextActiveCallables = Set.insert key (contextActiveCallables initial)}
          entered = withLoanedParameters loaned parameters $
            (startFunction current{lowerContext = active} (hidden <> parameters) (Just ownResult))
              {lowerCurrentKey = key, lowerDeclaredResult = Nothing, lowerFlexibleResult = flexible}
          (withReceiver, prologue) = case bound of
            Just held' ->
              let site = MutableReceiverSite key
                  retained = settledMutableLayout initial site held'
                  captured = CoreExpression at held' (CoreCapture 0 (CoreExpression at kind (CoreReadLocal env)))
                  (ready, carried) = projectRuntimeValue (contextTypes initial) entered retained captured
                  (next, held) = bindMutable ready site "$receiver" (coreExpressionType carried)
               in (next, [CoreStatement at (CoreDeclare held carried)])
            Nothing -> (entered, [])
          -- Past the end of any source, so no site made from one has a position.
          beyond index = fromMaybe zeroOffset (offsetFromInt (maxBound - index))
          argumentSpans = [at{spanStart = beyond index, spanEnd = beyond index} | index <- [1 .. length inputs]]
          -- The callee has a span of its own carrying the value's function type,
          -- which settles a generic implementation's parameters; a lent argument
          -- is read as the value its parameter holds.
          calleeSpan = at{spanStart = beyond (length inputs + 1), spanEnd = beyond (length inputs + 1)}
          lentTarget (ReferenceTypeValue True inner) = inner
          lentTarget other = other
          original = contextTypes (lowerContext current)
          receiverFacts =
            [(locatedSpan receiver, unformed held) | Just held <- [bound]
            , typeForSpan original (locatedSpan receiver) /= Just held]
          overlaid = withReceiver{lowerContext = (lowerContext withReceiver)
            {contextTypes = withFacts ((at, resultFact) : (calleeSpan, whole) : receiverFacts <> zip argumentSpans (map lentTarget inputFacts)) original}}
          target = case bound of
            Just _ -> Located (locatedSpan receiver) (NameExpression ("$receiver" :| []))
            Nothing -> receiver
          call = Located at (CallExpression
            (Located calleeSpan (MemberExpression target (Located calleeSpan member)))
            [Located spanValue (NameExpression (argumentName index :| [])) | (index, spanValue) <- zip [1 ..] argumentSpans])
          (afterBody, lowered)
            | member == "toText", null inputs, bound `elem` [Just CoreCharType, Just CoreBytesType] =
                lowerTextMethod lower (\_ _ -> Nothing) overlaid at calleeSpan target member []
            | otherwise = lower overlaid call
          context = (lowerContext afterBody)
            {contextTypes = original, contextActiveCallables = Set.delete key (contextActiveCallables (lowerContext afterBody))}
          before = length (contextRefusals (lowerContext current))
          -- Refusals inside point at made-up spans; one at the member says it.
          settled = if length (contextRefusals context) > before
            then refuse at ("the method value '" <> plain <> "'") current{lowerContext = context{contextRefusals = drop (length (contextRefusals context) - before) (contextRefusals context)}}
            else current{lowerContext = context}
          receiverType = maybe (case inputs of { self : _ -> self; [] -> CoreUnitType }) id bound
       in case lowered of
            Just (written, _)
              | length (contextRefusals context) == before
              , let body = if flexible && not (null receiverFacts)
                      then preserveRuntimeResult ownResult written else written
                    bodyKind = coreExpressionType body
              , flexible && hasRuntimeChoice bodyKind || bodyKind `elem` [ownResult, CoreNeverType] ->
                  let (ready, carried) = if flexible
                        then projectRuntimeValue original afterBody ownResult body
                        else (afterBody, body)
                      (_, completed) = closeLoaned ready at (CoreBlock prologue (Just carried))
                      lifted = CoreFunction key (hidden <> parameters) result completed
                      method = if traitValue then Nothing else Just receiverType
                      identity = fst (Text.breakOn "$runtime" key)
                      info = CoreClosureInfo (foldMap pure bound) plain identity False (isJust bound) method
                      template = CallableTemplate kind (MethodCallable original (contextModule initial) at receiver member bound solved whole)
                      observed = runtimeCarriers (coreExpressionType carried)
                      saved = lowerContext ready
                      registered = saved
                        { contextTypes = original
                        , contextActiveCallables = Set.delete key (contextActiveCallables saved)
                        , contextFunctions = lifted : contextFunctions saved
                        , contextClosures = Map.insert key info (contextClosures saved)
                        , contextObservedCallables = if flexible
                            then Map.insert key template (contextObservedCallables saved)
                            else contextObservedCallables saved
                        , contextObservedResults = if flexible && not (observed `Set.isSubsetOf` runtimeCarriers ownResult)
                            then Map.insertWith Set.union key observed (contextObservedResults saved)
                            else contextObservedResults saved
                        }
                   in (current{lowerContext = registered}, Just kind)
            _ | length (contextRefusals context) == before ->
                  halt at ("the method value '" <> plain <> "' without its checked result") settled
              | otherwise -> refused settled
 where
  initial = lowerContext current
  loaned = [index | (index, ReferenceTypeValue True _) <- zip [0 :: Int ..] inputFacts]
  flexible = not asynchronous
  inputs = zipWith carry [0 ..] requested
  carry index input
    | index `elem` loaned =
        settledMutableLayout initial (MutableParameterSite key index) input
    | otherwise = input
  checkedOwn = case checkedResult of
    CoreTupleType (own : _) | not (null loaned) -> own
    _ -> checkedResult
  ownResult
    | flexible = runtimeResultType checkedOwn
        (Map.findWithDefault Set.empty key (contextRuntimeResults initial))
    | otherwise = checkedOwn
  result
    | null loaned = ownResult
    | otherwise = CoreTupleType (ownResult : [input | (index, input) <- zip [0 ..] inputs, index `elem` loaned])
  kind = CoreFunctionType inputs result
  plain = snd (selectedMember member)
  traitValue = case locatedValue receiver of
    NameExpression ("::trait-method::" :| [_]) -> True
    _ -> False
  argumentName index = "$" <> Text.pack (show (index :: Int))
registerMethodValue _ current at _ _ _ _ _ _ = halt at "a method value without a settled native signature" current
