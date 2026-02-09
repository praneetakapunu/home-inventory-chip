#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

# Safety: never auto-commit; only sync if clean.
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Repo has uncommitted changes; refusing to sync." >&2
  git status --porcelain >&2
  exit 2
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "No 'origin' remote configured; nothing to sync." >&2
  exit 3
fi

# Fetch + fast-forward local if possible, then push.
git fetch origin --prune
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Try to fast-forward only (no merges).
if git rev-parse --verify "origin/${BRANCH}" >/dev/null 2>&1; then
  git pull --ff-only origin "$BRANCH"
fi

git push origin "$BRANCH"

echo "OK"
