#!/usr/bin/env bash
#
# Rebuild the compiler and replace the installed executable the shell and editor
# actually run, then prove that exact file against the current language.
#
# The failure this exists to stop is silent: a fix lands in the tree, the editor
# keeps reporting the old answer, and nothing says why — because the editor
# spawns an executable installed days ago, and every development build reports
# the same version, so no version check can tell the two apart. Installing to
# one directory is not enough on its own: `cabal install` writes to its own
# default directory, so an earlier install elsewhere on PATH keeps winning until
# something looks for it.
#
# Usage: scripts/refresh-install.sh [install-directory]
#   install-directory defaults to $HOME/.local/bin

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_dir="${1:-$HOME/.local/bin}"
fixture="$root/test-fixtures/tooling/RecentLanguage.pudu"

say() { printf '\n== %s\n' "$1"; }

say "Building"
cd "$root"
cabal build exe:pudu

say "Installing to $install_dir"
mkdir -p "$install_dir"
cabal install exe:pudu --installdir="$install_dir" --overwrite-policy=always

# Every copy PATH can reach, not only the one just written. A second copy
# earlier in PATH shadows the refresh and reintroduces the drift.
say "Copies of pudu on PATH"
found=()
while IFS= read -r line; do found+=("$line"); done < <(
  IFS=:
  for directory in $PATH; do
    [ -x "$directory/pudu" ] && printf '%s\n' "$directory/pudu"
  done | awk '!seen[$0]++'
)

for copy in "${found[@]}"; do printf '  %s\n' "$copy"; done

resolved="$(command -v pudu || true)"
if [ -z "$resolved" ]; then
  echo "pudu is not on PATH; add $install_dir to PATH and run again" >&2
  exit 1
fi

if [ "${#found[@]}" -gt 1 ] && [ "$resolved" != "$install_dir/pudu" ]; then
  cat >&2 <<EOF

$resolved comes before $install_dir/pudu on PATH, so the shell and editor keep
running the older copy. Remove it, or put $install_dir first in PATH, then run
this script again.
EOF
  exit 1
fi

# Every check below runs the resolved path rather than a worktree binary: what
# is proved has to be the file the editor will spawn.
say "Proving $resolved"
"$resolved" version

say "check accepts the current language"
"$resolved" check "$fixture"

say "the REPL accepts it too"
printf '2 in #{1, 2, 3}\n:quit\n' | "$resolved" repl >/dev/null

say "a real LSP session opens it with no diagnostics"
node "$root/test/lsp-session.mjs" "$resolved"

say "Refreshed: $resolved"
