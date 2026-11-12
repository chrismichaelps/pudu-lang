@AGENTS.md

# Claude Code

Always delegate:
- Any grep / search / find → searcher
- Any git command or history → git-helper
- Tests, builds, or long-running terminal commands → tester
- Other noisy shell work → shell

Keep the main Fable session focused on architecture, planning, and final decisions. Do not run noisy terminal or search work yourself.
