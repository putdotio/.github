#!/usr/bin/env bash
set -euo pipefail

rm -f "$RESULT"

if [ -n "$NOTES" ]; then
  echo "run=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

head="$(git rev-parse HEAD)"
base="$BASE_REF"
if [ -z "$base" ] && [ -n "$TAG_PATTERN" ]; then
  base="$(git describe --tags --abbrev=0 --match "$TAG_PATTERN" HEAD^ 2>/dev/null)" || base=""
fi
if [ -z "$base" ]; then
  echo "beta-notes: no base build to compare with; using the fallback" >&2
  echo "run=false" >> "$GITHUB_OUTPUT"
  exit 0
fi
if ! base="$(git rev-parse --verify --quiet "$base^{commit}")"; then
  echo "beta-notes: the base build is not in this checkout; check out with fetch-depth: 0" >&2
  echo "run=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

candidates="$(git log --format='%s' "$base..$head" \
  | grep -E '^(feat|fix|perf)(\([^)]*\))?!?: ' \
  | grep -cvE '^[a-z]+\((deps|ci|docs|test|build)\)')" || true
if [ "${candidates:-0}" -eq 0 ]; then
  echo "beta-notes: no user-facing commits in ${base:0:12}..${head:0:12}; using the fallback" >&2
  echo "run=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

prompt="$RUNNER_TEMP/beta-notes-prompt.md"
{
  cat "$GITHUB_ACTION_PATH/prompt.md"
  printf '\nApp: %s\nRepository: %s\nRange: %s..%s\n' "$APP" "$GITHUB_REPOSITORY" "$base" "$head"
} > "$prompt"

{
  echo "run=true"
  echo "prompt=$prompt"
} >> "$GITHUB_OUTPUT"
