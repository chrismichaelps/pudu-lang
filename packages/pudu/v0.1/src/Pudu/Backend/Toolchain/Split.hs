{-| @Backend.Toolchain.Split — one generated C unit as a shared header, a data
    unit, and function units that compile at the same time.

    The pass reads the emitted text as a sequence of top-level items, keeping
    the conditional directives each one sits inside. The header, which every
    unit includes, carries what may exist once per unit: directives, types,
    prototypes, inline helpers without state of their own, and read-only
    data. State that must exist once — every other piece of data — is defined
    in the data unit and declared `extern` in the header. Every other function
    is defined once, in the unit the size balance picks. -}
module Pudu.Backend.Toolchain.Split (SplitUnits (..), splitUnits) where

import Data.Char (isAlphaNum, isSpace)
import Data.List (sortOn)
import Data.Maybe (mapMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text

{-| The header every unit includes, the data unit, and the function units. -}
data SplitUnits = SplitUnits
  { splitHeader :: !Text
  , splitData :: !Text
  , splitFunctions :: ![Text]
  }
  deriving stock (Eq, Show)

data Kind = Directive | Passing | TypeItem | Prototype | Inline | Function | Data
  deriving stock (Eq, Show)

{-| A top-level item: its kind, its lines, and the conditional directives
    around it, each an opening line and the branch lines after it. -}
data Item = Item !Kind ![Text] ![(Text, [Text])]

{-| The units for a source split `count` ways. -}
splitUnits :: Int -> Text -> SplitUnits
splitUnits count source = SplitUnits
  { splitHeader = Text.unlines header
  , splitData = Text.unlines ("#include \"unit.h\"" : dataLines)
  , splitFunctions = [Text.unlines ("#include \"unit.h\"" : body) | body <- balanced]
  }
 where
  items = scan (Text.lines source)
  copied = Set.fromList (mapMaybe (\(Item kind text _) -> if kind == Inline then nameOf text else Nothing) items)
  (header, dataLines, functions) = foldr place ([], [], []) items
  place (Item kind text conditions) (headed, defined, bodies) = case kind of
    Prototype
      | maybe False (`Set.member` copied) (nameOf text) -> (text <> headed, defined, bodies)
      | otherwise -> (unstatic text <> headed, defined, bodies)
    Data
      | leading "extern" text || (readOnly text && not (listed text)) -> (text <> headed, defined, bodies)
      | otherwise -> (externs text <> headed, wrap conditions (unstatic text) <> defined, bodies)
    Function -> (prototypeOf text <> headed, defined, (size text, wrap conditions (unstatic text)) : bodies)
    _ -> (text <> headed, defined, bodies)
  balanced = map (concat . reverse . snd) (foldl' assign (replicate (max 1 count) (0 :: Int, [])) (sortOn (negate . fst) functions))
  assign bins (weight, body) =
    let lightest = snd (minimum (zip (map fst bins) [0 :: Int ..]))
     in [if index == lightest then (load + weight, body : held) else (load, held) | (index, (load, held)) <- zip [0 ..] bins]
  size = sum . map Text.length

{-| Top-level items, read line by line with the open conditionals. -}
scan :: [Text] -> [Item]
scan = go []
 where
  go _ [] = []
  go conditions (line : rest)
    | "#" `Text.isPrefixOf` stripped =
        let next
              | any (`directive` stripped) ["if", "ifdef", "ifndef"] = (line, []) : conditions
              | any (`directive` stripped) ["elif", "else"] = case conditions of
                  (opening, branches) : outer -> (opening, branches <> [line]) : outer
                  [] -> []
              | directive "endif" stripped = drop 1 conditions
              | otherwise = conditions
         in Item Directive [line] [] : go next rest
    | Text.null stripped || lonelyAttribute stripped = Item Passing [line] [] : go conditions rest
    | "/*" `Text.isPrefixOf` line =
        let (comment, after) = breakAfter ("*/" `Text.isInfixOf`) (line : rest)
         in Item Passing comment [] : go conditions after
    | otherwise =
        let (text, after) = gather 0 [] (line : rest)
         in Item (classify text) text conditions : go conditions after
   where
    stripped = Text.strip line

  gather :: Int -> [Text] -> [Text] -> ([Text], [Text])
  gather _ taken [] = (reverse taken, [])
  gather depth taken (line : rest) =
    let code = codeOf line
        depth' = depth + Text.count "{" code - Text.count "}" code
        ended = Text.strip code
     in if depth' == 0 && (";" `Text.isSuffixOf` ended || "}" `Text.isSuffixOf` ended)
          then (reverse (line : taken), rest)
          else gather depth' (line : taken) rest

  breakAfter stop lines' = case break stop lines' of
    (before, found : after) -> (before <> [found], after)
    (before, []) -> (before, [])

directive :: Text -> Text -> Bool
directive name line = case Text.words (Text.drop 1 line) of
  word : _ -> word == name
  [] -> False

lonelyAttribute :: Text -> Bool
lonelyAttribute line = "__attribute__((" `Text.isPrefixOf` line && "))" `Text.isSuffixOf` line

{-| A line with its literals emptied and its comments removed, for counting
    braces and reading shapes. -}
codeOf :: Text -> Text
codeOf = removeComments . emptyLiterals
 where
  emptyLiterals text = Text.pack (go False ' ' (Text.unpack text))
  go _ _ [] = []
  go False _ (c : cs)
    | c == '"' || c == '\'' = c : go True c cs
    | otherwise = c : go False ' ' cs
  go True quote ('\\' : _ : cs) = go True quote cs
  go True quote (c : cs)
    | c == quote = c : go False ' ' cs
    | otherwise = go True quote cs
  removeComments text = case Text.breakOn "/*" text of
    (before, after)
      | Text.null after -> text
      | otherwise -> before <> removeComments (Text.drop 2 (snd (Text.breakOn "*/" after)))

classify :: [Text] -> Kind
classify text
  | any (`Text.isPrefixOf` head') ["typedef", "struct", "union", "enum"] = TypeItem
  | "{" `Text.isInfixOf` head' && "(" `Text.isInfixOf` beforeBrace && not ("=" `Text.isInfixOf` fst (Text.breakOn "(" beforeBrace)) =
      if inlineWord beforeBrace && not holdsStatic then Inline else Function
  | ";" `Text.isSuffixOf` head' && not ("{" `Text.isInfixOf` head') && length (topSplit '=' head') == 1
      && functionDeclarator head' && not ("__attribute__((unused));" `Text.isSuffixOf` Text.filter (not . isSpace) head') = Prototype
  | otherwise = Data
 where
  head' = Text.strip (codeOf (Text.unwords text))
  beforeBrace = fst (Text.breakOn "{" head')
  holdsStatic = any (\line -> "static " `Text.isPrefixOf` Text.stripStart line && Text.length line > Text.length (Text.stripStart line)) (drop 1 text)

{-| A declarator ending in a parameter list, optionally followed by a symbol
    name, as a prototype is; a pointer to a function is data. -}
functionDeclarator :: Text -> Bool
functionDeclarator declaration =
  let body = Text.strip (Text.dropEnd 1 (Text.strip declaration))
      withoutName = case Text.breakOnEnd "__asm__" body of
        (before, _) | not (Text.null before) -> Text.strip (Text.dropEnd 7 before)
        _ -> body
      (callee, parameters) = Text.breakOn "(" withoutName
      named = Text.takeWhileEnd isNameChar (Text.stripEnd callee)
   in ")" `Text.isSuffixOf` withoutName && not (Text.null parameters)
        && not (Text.null named) && named /= "__attribute__"
        && not ("(*" `Text.isPrefixOf` Text.filter (not . isSpace) parameters)

isNameChar :: Char -> Bool
isNameChar c = isAlphaNum c || c == '_'

{-| `inline`, or a macro of the runtime's own that stands for it. -}
inlineWord :: Text -> Bool
inlineWord text = any (\word -> word == "inline" || "_INLINE" `Text.isSuffixOf` word) (Text.split (not . isNameChar) text)

leading :: Text -> [Text] -> Bool
leading word (first : _) = (word <> " ") `Text.isPrefixOf` first
leading _ [] = False

{-| An array whose initializer is a brace list: defined once, since code
    compares addresses into it, with its length written into the `extern`. -}
listed :: [Text] -> Bool
listed text = "[]" `Text.isInfixOf` beforeInit && "{" `Text.isPrefixOf` Text.stripStart afterInit
 where
  (beforeInit, afterInit) = case topSplit '=' (codeOf (Text.unwords text)) of
    declared : initial : _ -> (declared, initial)
    _ -> ("", "")

{-| The number of members a brace list holds. -}
members :: Text -> Int
members initial =
  let inner = Text.strip (Text.dropEnd 1 (Text.strip (Text.drop 1 (Text.strip initial))))
      pieces = filter (not . Text.null . Text.strip) (topSplit ',' inner)
   in length pieces

{-| Read-only data each unit may hold its own copy of. -}
readOnly :: [Text] -> Bool
readOnly text@(first : _) = case Text.words (dropOptional first) of
  -- A `const` before a pointer qualifies what it points at, not the
  -- variable, so only data with no pointer in its declaration is copied.
  "static" : "const" : _ -> not ("_Thread_local" `Text.isInfixOf` first) && not ("*" `Text.isInfixOf` declared)
  _ -> False
 where
  declared = case topSplit '=' (codeOf (Text.unwords text)) of
    found : _ -> found
    [] -> first
readOnly [] = False

dropOptional :: Text -> Text
dropOptional line = maybe line Text.stripStart (Text.stripPrefix "PUDU_OPTIONAL" line)

{-| The first line without its `static` (and `inline`), so the definition is
    reached from every unit. -}
unstatic :: [Text] -> [Text]
unstatic [] = []
unstatic (first : rest) = removeStorage first : rest

removeStorage :: Text -> Text
removeStorage line =
  let optional = "PUDU_OPTIONAL " `Text.isPrefixOf` line
      body = dropOptional line
      dropped = foldl' (\text word -> maybe text Text.stripStart (Text.stripPrefix word text)) body ["static ", "inline "]
   in (if optional then "PUDU_OPTIONAL " else "") <> dropped

prototypeOf :: [Text] -> [Text]
prototypeOf text = [removeStorage (Text.stripEnd (fst (Text.breakOn "{" (Text.unwords text)))) <> ";"]

{-| One `extern` declaration for each declarator of a data item. -}
externs :: [Text] -> [Text]
externs text =
  let declaration = removeStorage (Text.dropWhileEnd (== ';') (Text.strip (codeOf (Text.unwords text))))
      sized piece = case topSplit '=' piece of
        declared : initial : _
          | "[]" `Text.isInfixOf` declared && "{" `Text.isPrefixOf` Text.stripStart initial ->
              let (front, back) = Text.breakOn "[]" declared
               in front <> "[" <> Text.pack (show (members (Text.strip (Text.intercalate "=" (initial : drop 2 (topSplit '=' piece)))))) <> "]" <> Text.drop 2 back
        declared : _ -> declared
        [] -> piece
      declarators = map (Text.strip . sized) (topSplit ',' declaration)
   in case declarators of
        first : others ->
          -- Later declarators share the first one's specifiers: every word
          -- of it but the declared name.
          let specifiers = Text.unwords (init (Text.words first))
           in ["extern " <> first <> ";"] <> ["extern " <> specifiers <> " " <> other <> ";" | other <- others]
        [] -> []

{-| A conditional stack replayed around an item placed elsewhere. -}
wrap :: [(Text, [Text])] -> [Text] -> [Text]
wrap conditions text =
  concat [opening : branches | (opening, branches) <- reverse conditions] <> text <> map (const "#endif") conditions

{-| Pieces separated by a character outside every bracket. -}
topSplit :: Char -> Text -> [Text]
topSplit separator = map Text.pack . go (0 :: Int) [] . Text.unpack
 where
  go _ current [] = [reverse current]
  go depth current (c : cs)
    | c `elem` ("([{" :: String) = go (depth + 1) (c : current) cs
    | c `elem` (")]}" :: String) = go (depth - 1) (c : current) cs
    | c == separator && depth == 0 = reverse current : go depth [] cs
    | otherwise = go depth (c : current) cs

{-| The name a function or prototype declares. -}
nameOf :: [Text] -> Maybe Text
nameOf text =
  let declaration = fst (Text.breakOn "{" (codeOf (Text.unwords text)))
      callee = Text.stripEnd (fst (Text.breakOn "(" declaration))
      name = Text.takeWhileEnd isNameChar callee
   in if Text.null name then Nothing else Just name
