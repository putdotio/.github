#!/usr/bin/env bash
set -euo pipefail

notes=""
source=fallback
if [ -s "$RESULT" ]; then
  if jq -e '.is_error' "$RESULT" > /dev/null; then
    echo "beta-notes: Claude failed: $(jq -r '.result // .subtype' "$RESULT" | head -c 300)" >&2
  fi
  bullets="$(jq -r 'select(.is_error | not) | .structured_output.bullets[]? | select(type == "string") | select(test("[\r\n]|://") | not) | sub("^[-*• ]+"; "") | sub("[. ]+$"; "") | select(length > 0) | "- " + .' "$RESULT")" || bullets=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    candidate="${notes:+$notes$'\n'}$line"
    [ "${#candidate}" -le "$MAX_LENGTH" ] || break
    notes="$candidate"
  done <<< "$bullets"
  [ -z "$notes" ] || source=claude
fi
if [ -z "$notes" ]; then
  notes="$FALLBACK"
fi

delimiter="EOF_${RANDOM}${RANDOM}${RANDOM}"
{
  echo "source=$source"
  echo "notes<<$delimiter"
  echo "$notes"
  echo "$delimiter"
} >> "$GITHUB_OUTPUT"
{
  echo "### Beta notes ($source)"
  echo
  echo "$notes"
} >> "$GITHUB_STEP_SUMMARY"
