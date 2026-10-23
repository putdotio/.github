#!/usr/bin/env bash
# Runs Claude Code headless on the prompt and writes its JSON result to RESULT.
# claude-code-action is avoided: its Agent SDK launch is rejected as
# "Credit balance is too low" (anthropics/claude-code-action#1901).
set -euo pipefail

version=2.1.309
for attempt in 1 2 3; do
  curl -fsSL https://claude.ai/install.sh | bash -s -- "$version" > /dev/null && break
  [ "$attempt" -lt 3 ] || { echo "beta-notes: could not install Claude Code" >&2; exit 1; }
  sleep 5
done
export PATH="$HOME/.local/bin:$PATH"

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  unset ANTHROPIC_FEDERATION_RULE_ID ANTHROPIC_ORGANIZATION_ID ANTHROPIC_SERVICE_ACCOUNT_ID ANTHROPIC_WORKSPACE_ID
else
  unset ANTHROPIC_API_KEY
  if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
    echo "beta-notes: federation needs id-token: write on the job" >&2
    exit 1
  fi
  export ANTHROPIC_IDENTITY_TOKEN_FILE="$RUNNER_TEMP/beta-notes-identity-token"
  curl -fsS -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
    "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=https://api.anthropic.com" \
    | jq -er .value > "$ANTHROPIC_IDENTITY_TOKEN_FILE"
fi

claude -p "$(cat "$PROMPT")" \
  --model "$MODEL" \
  --max-turns "$MAX_TURNS" \
  --allowedTools Read Grep Glob "Bash(git log:*)" "Bash(git show:*)" "Bash(git diff:*)" "Bash(gh pr view:*)" \
  --json-schema "$(cat "$GITHUB_ACTION_PATH/schema.json")" \
  --output-format json < /dev/null > "$RESULT"
