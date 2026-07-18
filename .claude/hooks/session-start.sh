#!/usr/bin/env bash
#
# SessionStart hook for Claude Code on the web.
#
# Prepares a fresh remote session so agents can build and preview this Hugo
# site. It does two things, both of which a fresh clone is missing:
#
#   1. Initialises the theme submodule (the site will NOT build without it).
#   2. Installs the Hugo binary (pinned, non-extended) if it is not present.
#
# The hook is idempotent — safe to run repeatedly. It only does work in the
# remote (web) environment; run locally it exits immediately, so it never
# touches your own machine's Hugo install.
#
# See instructions_for_myself.md for how the site is built and deployed.

set -euo pipefail

# Only act in Claude Code on the web. Do nothing locally.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

# Pinned Hugo version. Must stay >= 0.146.0 (see instructions_for_myself.md).
# To upgrade, bump this to any tag from https://github.com/gohugoio/hugo/tags
# and start a new session. The non-extended build is enough (the theme sets
# `extended = false`).
HUGO_VERSION="v0.164.0"

# 1. Theme submodule. `hugo-simple` is vendored as a git submodule and is empty
#    on a fresh clone; Hugo aborts the build if the theme is missing.
echo "[session-start] Initialising theme submodule…"
git submodule update --init themes/hugo-simple

# Put Go-installed binaries on PATH — for the rest of this hook, and (via
# CLAUDE_ENV_FILE) for every command the agent runs this session.
GOBIN_DIR="$(go env GOPATH)/bin"
export PATH="$GOBIN_DIR:$PATH"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$GOBIN_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# 2. Hugo binary. Install only if the pinned version is not already present.
if command -v hugo >/dev/null 2>&1 && hugo version | grep -q "$HUGO_VERSION"; then
  echo "[session-start] Hugo already installed: $(hugo version)"
else
  echo "[session-start] Installing Hugo $HUGO_VERSION (can take ~90s on a cold cache)…"
  # Prebuilt release binaries from github.com are blocked by the egress policy,
  # so build from source through the Go module proxy (an allowed host). CGO off
  # gives the standard (non-extended) Hugo, which is all this site needs.
  CGO_ENABLED=0 go install "github.com/gohugoio/hugo@${HUGO_VERSION}"
  echo "[session-start] Installed: $(hugo version)"
fi

echo "[session-start] Ready. Build with 'hugo'; preview with 'hugo server -D'."
