{-| @Repl.Command.Module — parses the colon command vocabulary -}
module Pudu.Repl.Command
  ( Command (..)
  , Entry (..)
  , commandHelp
  , commandNames
  , parseEntry
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

{-| @Repl.Command.Value — the closed set of colon commands -}
data Command
  = Help
  | Quit
  | Load !Text
  | Reload
  | Reset
  | Browse !(Maybe Text)
  | Edit !(Maybe Text)
  | ShowType !Text
  | ShowTokens !Text
  | ShowAst !Text
  | ShowContext
  | ShowInfo !Text
  | ShowKind !Text
  | ShowInstances !Text
  | ShowSetting !Text
  | ClearSetting !Text
  | ShowState !Text
  | ShowDoc !Text
  | Search !Text
  | BeginBlock
  | EndBlock
  | Unknown !Text
  deriving stock (Eq, Show)

{-| @Repl.Command.Entry — one line is either a command or program input -}
data Entry
  = CommandEntry !Command
  | SourceEntry !Text
  | BlankEntry
  deriving stock (Eq, Show)

{-| Parse one input line. A leading `:` introduces a command; everything else is
    program text. Command names may be abbreviated to any unambiguous prefix,
    matching the one-letter forms a prompt reader already expects. -}
parseEntry :: Text -> Entry
parseEntry raw
  | Text.null trimmed = BlankEntry
  | isCommentLine trimmed = BlankEntry
  | trimmed == ":{" = CommandEntry BeginBlock
  | trimmed == ":}" = CommandEntry EndBlock
  | Text.isPrefixOf ":" trimmed = CommandEntry (parseCommand (Text.drop 1 trimmed))
  | otherwise = SourceEntry raw
 where
  trimmed = Text.strip raw
  isCommentLine text =
    Text.isPrefixOf "//" text && not (Text.isPrefixOf "///" text)
      && not (Text.any (\c -> c == '\n' || c == '\r') text)

parseCommand :: Text -> Command
parseCommand body = case resolveName name of
  Nothing -> Unknown name
  Just canonical -> build canonical (Text.strip argument)
 where
  (name, argument) = Text.break isSpace (Text.strip body)
  isSpace character = character == ' ' || character == '\t'

build :: Text -> Text -> Command
build canonical argument = case canonical of
  "help" -> Help
  "quit" -> Quit
  "load" -> Load argument
  "reload" -> Reload
  "reset" -> Reset
  "browse" -> Browse (if Text.null argument then Nothing else Just argument)
  "edit" -> Edit (if Text.null argument then Nothing else Just argument)
  "type" -> ShowType argument
  "tokens" -> ShowTokens argument
  "ast" -> ShowAst argument
  "context" -> ShowContext
  "info" -> ShowInfo argument
  "kind" -> ShowKind argument
  "instances" -> ShowInstances argument
  "set" -> ShowSetting argument
  "unset" -> ClearSetting argument
  "show" -> ShowState argument
  "doc" -> ShowDoc argument
  "search" -> Search argument
  _ -> Unknown canonical

{-| An abbreviation resolves to the first command that it prefixes, so the
    established one-letter forms stay stable as commands are added. An exact
    spelling always wins over a prefix. -}
resolveName :: Text -> Maybe Text
resolveName typed
  | Text.null typed = Nothing
  | typed == "?" = Just "help"
  | typed `elem` commandNames = Just typed
  | otherwise = case filter (Text.isPrefixOf typed) commandNames of
      first : _ -> Just first
      [] -> Nothing

{-| Order is priority: the first command an abbreviation prefixes wins. -}
commandNames :: [Text]
commandNames =
  [ "quit", "help", "load", "reload", "reset"
  , "type", "info", "kind", "instances"
  , "doc", "search"
  , "tokens", "ast", "browse", "context", "edit", "show", "set", "unset"
  ]

commandHelp :: [(Text, Text)]
commandHelp =
  [ (":help, :?", "show this message")
  , (":quit", "leave the session")
  , (":load <file>", "compile a file and use it as the session context")
  , (":reload", "recompile the loaded file")
  , (":reset", "forget every binding and declaration entered here")
  , (":browse [module]", "list what a module or the session exports")
  , (":edit [file]", "open an editor and reload on exit")
  , (":context", "show the declarations and bindings currently in scope")
  , (":type <expr>", "report the type of an expression")
  , (":info <name>", "show how a name is declared and what implements it")
  , (":kind <type>", "show how many type arguments a type takes")
  , (":instances <type>", "list the traits implemented for a type")
  , (":set +t", "print the type after each result; :unset +t stops")
  , (":set +s", "print how long each entry took; :unset +s stops")
  , (":set +trunc", "truncate large collections; :unset +trunc shows full")
  , (":show <topic>", "bindings, declarations, imports, or settings")
  , (":doc <name>", "show a name's documentation and inferred type")
  , (":search <query>", "find a name, or a type such as Array[a] -> a")
  , (":tokens <text>", "show the token stream for one line")
  , (":ast <text>", "show the parsed structure of one line")
  , (":{ ... :}", "enter a multi-line block")
  ]
