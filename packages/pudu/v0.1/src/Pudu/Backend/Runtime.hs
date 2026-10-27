{-| @Pudu.Backend.Runtime — the C runtime every natively built program
    carries inside it.

    The text is owned here as Haskell so the compiler ships self-contained:
    no data file to locate at run time, no include beyond the C standard
    library. The rendering matches [[Pudu.Diagnostic.Render]] exactly — the
    headline, the location line, the gutter and excerpt, the caret, and the
    help line — and [[Pudu.Backend.Emit]] bakes the site data from the same
    Haskell sources, so native refusals read byte-for-byte like interpreted
    ones. Checked helpers are defined for every input, including
    `INT64_MIN / -1` and `INT64_MIN` negation, which would be undefined
    behaviour in plain C and are refusals in Pudu.

    The runtime is a list of named parts, not one blob: [[Pudu.Backend.Emit]]
    emits only the parts a program's operations actually call. An unused
    `static inline` function still draws `-Wunused-function` from clang under
    `-Wall -Wextra`, and the toolchain contract is that a native build is
    warning-free, so dead helpers cannot be written at all.
-}
module Pudu.Backend.Runtime
  ( RuntimePart (..)
  , runtimeRevision
  , runtimeParts
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Comptime.Limits (callDepthLimit)

{-| The runtime contract revision baked into every generated program's header
    comment. It changes only when the runtime's behaviour or interface does. -}
runtimeRevision :: Text
runtimeRevision = "2"

{-| @Backend.Runtime.Part — one named, self-contained piece of the runtime.

    The name is what [[Pudu.Backend.Emit]] selects on; the lines are written in
    order, with a blank line after each selected part. Parts are independent:
    a part never calls a helper outside itself except where its lines show it
    (`pudu_fail` is a prerequisite of every checked helper, and emission
    selects the whole prerequisite set together). -}
data RuntimePart = RuntimePart
  { runtimePartName :: !Text
  , runtimePartLines :: ![Text]
  }

{-| Every runtime part, in emission order. -}
runtimeParts :: [RuntimePart]
runtimeParts =
  [ RuntimePart "prelude" preludeLines
  , RuntimePart "site" siteLines
  , RuntimePart "colored" coloredLines
  , RuntimePart "fail" failLines
  , RuntimePart "call_depth" callDepthLines
  , RuntimePart "add" addLines
  , RuntimePart "sub" subLines
  , RuntimePart "mul" mulLines
  , RuntimePart "div" divLines
  , RuntimePart "rem" remLines
  , RuntimePart "neg" negLines
  , RuntimePart "print_int" printIntLines
  , RuntimePart "print_bool" printBoolLines
  , RuntimePart "print_str" printStrLines
  , RuntimePart "status" statusLines
  ]

preludeLines :: [Text]
preludeLines =
  [ "/* pudu native runtime revision " <> runtimeRevision <> " */"
  , ""
  , "#include <inttypes.h>"
  , "#include <stdint.h>"
  , "#include <stdio.h>"
  , "#include <stdlib.h>"
  , "#include <string.h>"
  , ""
  , "#if defined(_WIN32)"
  , "#include <io.h>"
  , "#define PUDU_ISATTY _isatty"
  , "#else"
  , "#include <unistd.h>"
  , "#define PUDU_ISATTY isatty"
  , "#endif"
  ]

siteLines :: [Text]
siteLines =
  [ "/* One refusal site: the operation's span as the interpreter sees it. */"
  , "typedef struct {"
  , "  const char *file;"
  , "  int line;"
  , "  int column;"
  , "  const char *code;"
  , "  const char *message;"
  , "  const char *help;"
  , "  const char *line_text;"
  , "  int caret_indent;"
  , "  int caret_width;"
  , "  int multiline;"
  , "  int has_excerpt;"
  , "} pudu_site;"
  ]

coloredLines :: [Text]
coloredLines =
  [ "static inline int pudu_colored(void) {"
  , "  return PUDU_ISATTY(1) && getenv(\"NO_COLOR\") == NULL;"
  , "}"
  ]

failLines :: [Text]
failLines =
  [ "/* Print the refusal and leave with the interpreter's status for one. */"
  , "static inline void pudu_fail(const pudu_site *site) {"
  , "  int colored = pudu_colored();"
  , "  int index;"
  , "  if (colored) fputs(\"\\x1b[31m\", stderr);"
  , "  fprintf(stderr, \"error[%s]\", site->code);"
  , "  if (colored) fputs(\"\\x1b[0m\", stderr);"
  , "  fprintf(stderr, \": %s\\n\", site->message);"
  , "  fprintf(stderr, \"  --> %s:%d:%d\\n\", site->file, site->line, site->column);"
  , "  if (site->has_excerpt) {"
  , "    char gutter[24];"
  , "    int width;"
  , "    snprintf(gutter, sizeof gutter, \"%d\", site->line);"
  , "    width = (int)strlen(gutter);"
  , "    fprintf(stderr, \" %*s |\\n\", width, \"\");"
  , "    fprintf(stderr, \" %s | %s\\n\", gutter, site->line_text);"
  , "    fprintf(stderr, \" %*s | \", width, \"\");"
  , "    if (colored) fputs(\"\\x1b[31m\", stderr);"
  , "    for (index = 0; index < site->caret_indent; index += 1) fputc(' ', stderr);"
  , "    for (index = 0; index < site->caret_width; index += 1) fputc('^', stderr);"
  , "    if (colored) fputs(\"\\x1b[0m\", stderr);"
  , "    if (site->multiline) fputs(\" ...\", stderr);"
  , "    fputc('\\n', stderr);"
  , "  }"
  , "  if (site->help != NULL) {"
  , "    fputs(\"   = \", stderr);"
  , "    if (colored) fputs(\"\\x1b[36m\", stderr);"
  , "    fputs(\"help\", stderr);"
  , "    if (colored) fputs(\"\\x1b[0m\", stderr);"
  , "    fprintf(stderr, \": %s\\n\", site->help);"
  , "  }"
  , "  fflush(stderr);"
  , "  exit(1);"
  , "}"
  ]

{-| The evaluator's call-depth bound, as the evaluator counts it: the entry
    runs at depth 1, the check is `depth > limit` *before* the increment, and
    the refusal lands on the call's own site. The bound is written from
    [[Pudu.Comptime.Limits]] so the runtime and the evaluator cannot drift. -}
callDepthLines :: [Text]
callDepthLines =
  [ "/* The evaluator's call-depth bound; the entry starts at depth 1. */"
  , "static int64_t pudu_depth = 0;"
  , ""
  , "static inline void pudu_enter(const pudu_site *site) {"
  , "  if (pudu_depth > " <> Text.pack (show callDepthLimit) <> ") pudu_fail(site);"
  , "  pudu_depth += 1;"
  , "}"
  ]

addLines :: [Text]
addLines =
  [ "static inline int64_t pudu_add(int64_t a, int64_t b, const pudu_site *site) {"
  , "  if ((b > 0 && a > INT64_MAX - b) || (b < 0 && a < INT64_MIN - b)) pudu_fail(site);"
  , "  return a + b;"
  , "}"
  ]

subLines :: [Text]
subLines =
  [ "static inline int64_t pudu_sub(int64_t a, int64_t b, const pudu_site *site) {"
  , "  if ((b < 0 && a > INT64_MAX + b) || (b > 0 && a < INT64_MIN + b)) pudu_fail(site);"
  , "  return a - b;"
  , "}"
  ]

mulLines :: [Text]
mulLines =
  [ "static inline int64_t pudu_mul(int64_t a, int64_t b, const pudu_site *site) {"
  , "  if (a == 0 || b == 0) return 0;"
  , "  if (a == -1 && b == INT64_MIN) pudu_fail(site);"
  , "  if (b == -1 && a == INT64_MIN) pudu_fail(site);"
  , "  if (a > 0) {"
  , "    if (b > 0) { if (a > INT64_MAX / b) pudu_fail(site); }"
  , "    else { if (b < INT64_MIN / a) pudu_fail(site); }"
  , "  } else {"
  , "    if (b > 0) { if (a < INT64_MIN / b) pudu_fail(site); }"
  , "    else { if (a < INT64_MAX / b) pudu_fail(site); }"
  , "  }"
  , "  return a * b;"
  , "}"
  ]

divLines :: [Text]
divLines =
  [ "static inline int64_t pudu_div(int64_t a, int64_t b, const pudu_site *zero, const pudu_site *overflow) {"
  , "  if (b == 0) pudu_fail(zero);"
  , "  if (a == INT64_MIN && b == -1) pudu_fail(overflow);"
  , "  return a / b;"
  , "}"
  ]

remLines :: [Text]
remLines =
  [ "/* `INT64_MIN % -1` is 0 in the evaluator; plain C would trap. */"
  , "static inline int64_t pudu_rem(int64_t a, int64_t b, const pudu_site *zero) {"
  , "  if (b == 0) pudu_fail(zero);"
  , "  if (b == -1) return 0;"
  , "  return a % b;"
  , "}"
  ]

negLines :: [Text]
negLines =
  [ "static inline int64_t pudu_neg(int64_t a, const pudu_site *site) {"
  , "  if (a == INT64_MIN) pudu_fail(site);"
  , "  return -a;"
  , "}"
  ]

printIntLines :: [Text]
printIntLines =
  [ "static inline void pudu_print_int(int64_t value) {"
  , "  printf(\"%\" PRId64 \"\\n\", value);"
  , "  fflush(stdout);"
  , "}"
  ]

printBoolLines :: [Text]
printBoolLines =
  [ "static inline void pudu_print_bool(int value) {"
  , "  fputs(value ? \"true\\n\" : \"false\\n\", stdout);"
  , "  fflush(stdout);"
  , "}"
  ]

printStrLines :: [Text]
printStrLines =
  [ "static inline void pudu_print_str(const char *bytes, size_t length) {"
  , "  fwrite(bytes, 1, length, stdout);"
  , "  fputc('\\n', stdout);"
  , "  fflush(stdout);"
  , "}"
  ]

statusLines :: [Text]
statusLines =
  [ "/* The interpreter's exit-status clamp: 0 stays 0, everything else is 1..255. */"
  , "static inline int pudu_status(int64_t value) {"
  , "  if (value == 0) return 0;"
  , "  if (value < 1) return 1;"
  , "  if (value > 255) return 255;"
  , "  return (int)value;"
  , "}"
  ]
