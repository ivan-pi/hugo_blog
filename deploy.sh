#!/usr/bin/env bash
#
# Deploy the rendered site to GitHub Pages.
#
# This builds the site into ./public and pushes that directory to the GitHub
# Pages repository served at https://ivan-pi.github.io. For this to work,
# ./public must already be a clone of that Pages repo — see the
# "First-time deployment setup" section in instructions_for_myself.md.
#
# Usage:
#   ./deploy.sh                       # commit message defaults to a timestamp
#   ./deploy.sh "your commit message"

set -euo pipefail

green() { printf '\033[0;32m%s\033[0m\n' "$1"; }

green "Building the site with Hugo..."

# Build into ./public. Drafts are excluded (this is a production build).
# `set -e` above means a failed build aborts the script here, so a broken
# site is never pushed.
hugo --gc --minify

# ./public must be the *Pages* repo clone. If it is not a git repository,
# the git commands below would silently operate on the source repo instead,
# so refuse to continue.
if [ ! -d public/.git ]; then
  echo "Error: ./public is not a git repository." >&2
  echo "Set it up first — see 'First-time deployment setup' in instructions_for_myself.md." >&2
  exit 1
fi

green "Publishing the rendered site to GitHub Pages..."
cd public

# Stage everything, including deletions of pages that no longer exist.
git add -A

# Use the supplied message, or a timestamp by default.
msg="rebuilding site $(date)"
if [ "$#" -ge 1 ]; then msg="$1"; fi

if git diff --cached --quiet; then
  green "No changes to publish."
else
  git commit -m "$msg"
  # Force push: the Pages branch history is routinely rewritten.
  git push origin master --force
  green "Done. The site should be live within a couple of minutes."
fi

cd ..
