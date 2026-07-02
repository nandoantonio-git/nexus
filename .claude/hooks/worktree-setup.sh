#!/usr/bin/env bash
# SessionStart hook: make a fresh `claude --worktree` checkout dev-ready.
# After .worktreeinclude copies the env files, a new worktree still needs two
# things: its own node_modules (never shared between worktrees) and a dev port
# that won't collide with another worktree's `pnpm dev`. No-ops in the main
# checkout and on resume/compact once node_modules exists.
set -uo pipefail

cat >/dev/null 2>&1 || true   # drain the SessionStart JSON payload on stdin

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0

# Act only inside a linked worktree. In the main checkout --git-dir equals
# --git-common-dir; a linked worktree's --git-dir lives under
# <common>/worktrees/<name>, so the two paths differ.
[ "$(git rev-parse --git-dir)" = "$(git rev-parse --git-common-dir)" ] && exit 0

# `claude -w feat/86` can't put a `/` in the worktree dir name, so it sanitizes
# to `feat+86` and names the branch `worktree-feat+86`. The dir name is fine, but
# the branch should be the slashed form the user actually typed. Recover it:
# strip the `worktree-` prefix and turn `+` back into `/`.
branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
case "$branch" in
  worktree-*)
    intended=${branch#worktree-}
    intended=${intended//+//}   # +  ->  /  (inverse of claude's path sanitising)
    if [ "$intended" != "$branch" ]; then
      if git show-ref --verify --quiet "refs/heads/$intended"; then
        echo "worktree-setup: leaving '$branch' (target '$intended' already exists)" >&2
      elif git branch -m "$branch" "$intended"; then
        echo "worktree-setup: renamed branch '$branch' -> '$intended'" >&2
      fi
    fi
    ;;
esac

# Fresh install only when deps are absent, so resume/compact re-runs are instant.
if [ ! -d node_modules ]; then
  echo "worktree-setup: pnpm install (fresh worktree)..." >&2
  pnpm install --frozen-lockfile >&2 \
    || echo "worktree-setup: install failed - run 'pnpm install' manually" >&2
fi

# Stable per-worktree dev port in 3001-4000, derived from the worktree name so
# it stays the same across sessions. 3000 stays reserved for the main checkout.
name=$(basename "$root")
port=$(( 3001 + $(printf '%s' "$name" | cksum | cut -d' ' -f1) % 1000 ))

# CLAUDE_ENV_FILE persists vars into this session's Bash tool calls. turbo
# forwards everything (globalPassThroughEnv: ["*"]), so `pnpm dev` binds next dev
# to $port. playwright.config.ts reads PORT too (falls back to 3000), so e2e in
# this worktree targets $port as well — no collision with the main checkout.
[ -n "${CLAUDE_ENV_FILE:-}" ] && printf 'PORT=%s\n' "$port" >> "$CLAUDE_ENV_FILE"

# A SessionStart hook's stdout is injected into Claude's context.
echo "Worktree '$name' is dev-ready. PORT=$port is set for both 'pnpm dev' and e2e."
