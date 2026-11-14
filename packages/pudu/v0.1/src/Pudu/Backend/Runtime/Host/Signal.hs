{-| @Backend.Runtime.Host.Signal — the request to stop that arrives from outside the program, as `Pudu.Eval.Signal` answers it. -}
module Pudu.Backend.Runtime.Host.Signal (hostSignalParts) where

import Data.Text (Text)

{-| Each part: its name, the parts it needs, and its lines. -}
hostSignalParts :: [(Text, [Text], [Text])]
hostSignalParts =
  [ ("host_signals", ["host_optional"],
      [ "#include <signal.h>"
      , "/* One flag for the whole process; the handler only sets it. */"
      , "PUDU_OPTIONAL static volatile sig_atomic_t pudu_host_stop_asked = 0;"
      , "PUDU_OPTIONAL static int pudu_host_stop_watched = 0;"
      , "PUDU_OPTIONAL static void pudu_host_stop_record(int signal_number) { (void)signal_number; pudu_host_stop_asked = 1; }"
      ])
  , ("host_signal_watch", ["host_signals"],
      [ "/* Whether the terminate and interrupt requests are observed from here on. */"
      , "static int pudu_host_signal_watch(void) {"
      , "#if defined(_WIN32)"
      , "  return 0;"
      , "#else"
      , "  if (!pudu_host_stop_watched) {"
      , "    struct sigaction recorded;"
      , "    memset(&recorded, 0, sizeof recorded);"
      , "    recorded.sa_handler = pudu_host_stop_record;"
      , "    (void)sigemptyset(&recorded.sa_mask);"
      , "    recorded.sa_flags = SA_RESTART;"
      , "    (void)sigaction(SIGTERM, &recorded, NULL);"
      , "    (void)sigaction(SIGINT, &recorded, NULL);"
      , "    pudu_host_stop_watched = 1;"
      , "  }"
      , "  return 1;"
      , "#endif"
      , "}"
      ])
  , ("host_signal_requested", ["host_signals"],
      [ "PUDU_OPTIONAL static int pudu_host_signal_requested(void) { return pudu_host_stop_asked != 0; }"
      ])
  ]
