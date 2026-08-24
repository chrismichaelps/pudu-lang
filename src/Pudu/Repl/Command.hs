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
  | Browse
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
    matching the convention a Haskell user already knows from `:l` and `:t`. -}
parseEntry :: Text -> Entry
parseEntry raw
  | Text.null trimmed = BlankEntry
  | trimmed == ":{" = CommandEntry BeginBlock
  | trimmed == ":}" = CommandEntry EndBlock
  | Text.isPrefixOf ":" trimmed = CommandEntry (parseCommand (Text.drop 1 trimmed))
  | otherwise = SourceEntry raw
 where
  trimmed = Text.strip raw

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
  "browse" -> Browse
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
  , "tokens", "ast", "browse", "context", "show", "set", "unset"
  ]

commandHelp :: [(Text, Text)]
commandHelp =
  [ (":help, :?", "show this message")
  , (":quit", "leave the session")
  , (":load <file>", "compile a file and use it as the session context")
  , (":reload", "recompile the loaded file")
  , (":reset", "forget every binding and declaration entered here")
  , (":browse", "list what the session context exports")
  , (":context", "show the declarations and bindings currently in scope")
  , (":type <expr>", "report the type of an expression")
  , (":info <name>", "show how a name is declared and what implements it")
  , (":kind <type>", "show how many type arguments a type takes")
  , (":instances <type>", "list the traits implemented for a type")
  , (":set +t", "print the type after each result; :unset +t stops")
  , (":set +s", "print how long each entry took; :unset +s stops")
  , (":show <topic>", "bindings, imports, declarations, or settings")
  , (":doc <name>", "show a name's documentation and inferred type")
  , (":search <query>", "find a name, or a type such as Array[a] -> a")
  , (":tokens <text>", "show the token stream for one line")
  , (":ast <text>", "show the parsed structure of one line")
  , (":{ ... :}", "enter a multi-line block")
  ]
