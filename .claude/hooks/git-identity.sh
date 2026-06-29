#!/usr/bin/env bash
# SessionStart hook: attribute commits to the repo owner, not the Claude Code
# cloud container's baked-in identity (Claude <noreply@anthropic.com>), which
# maps to no GitHub account and shows up as "claude" with no link to the user.
#
# Sets a repo-local identity ONLY when the effective email is missing or the
# Anthropic default, so a correctly-configured local checkout is left untouched.
# Repo-local config (.git/config) overrides the container's global gitconfig.
set -uo pipefail

cat >/dev/null 2>&1 || true   # drain the SessionStart JSON payload on stdin

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0

current_email=$(git config user.email 2>/dev/null || true)
case "$current_email" in
  "" | "noreply@anthropic.com")
    git config user.name  "Thomas"
    git config user.email "thomasalmeidar@gmail.com"
    # A SessionStart hook's stderr surfaces in the session log.
    echo "git-identity: commit author set to Thomas <thomasalmeidar@gmail.com>." >&2
    ;;
esac
