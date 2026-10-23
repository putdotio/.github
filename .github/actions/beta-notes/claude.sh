#!/usr/bin/env bash
set -euo pipefail

version=2.1.309
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) platform=linux-x64 sha=4d704a8aecbe038affa3000f498ae17c1b4f753add8facb8764120affc99b658 ;;
  Linux-aarch64 | Linux-arm64) platform=linux-arm64 sha=9796dd26899337f687739a0b39a7353b639f062a3436a7b941fcf19a1b757a9b ;;
  Darwin-arm64) platform=darwin-arm64 sha=5eadc0009cdcdbc0d06e58110d7b2baf88ced6088b1c33a60a21217fe410619c ;;
  Darwin-x86_64) platform=darwin-x64 sha=200e0d775ae55c040db3bb8db8de3e22efcddbd7e0abff5ab50dd10f6853425d ;;
  *) echo "beta-notes: no Claude Code build for $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac
claude="$RUNNER_TEMP/beta-notes-claude-$version"
curl -fsSL --retry 3 "https://downloads.claude.ai/claude-code-releases/$version/$platform/claude" -o "$claude"
if command -v sha256sum > /dev/null; then
  actual="$(sha256sum "$claude" | cut -d' ' -f1)"
else
  actual="$(shasum -a 256 "$claude" | cut -d' ' -f1)"
fi
if [ "$actual" != "$sha" ]; then
  echo "beta-notes: Claude Code $version $platform checksum mismatch" >&2
  exit 1
fi
chmod +x "$claude"

refresh=""
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  unset ANTHROPIC_FEDERATION_RULE_ID ANTHROPIC_ORGANIZATION_ID ANTHROPIC_SERVICE_ACCOUNT_ID ANTHROPIC_WORKSPACE_ID
else
  unset ANTHROPIC_API_KEY
  if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
    echo "beta-notes: federation needs id-token: write on the job" >&2
    exit 1
  fi
  request_url="$ACTIONS_ID_TOKEN_REQUEST_URL"
  request_token="$ACTIONS_ID_TOKEN_REQUEST_TOKEN"
  unset ACTIONS_ID_TOKEN_REQUEST_URL ACTIONS_ID_TOKEN_REQUEST_TOKEN

  dir="$RUNNER_TEMP/beta-notes-federation"
  rm -rf "$dir"
  (umask 077 && mkdir -p "$dir/configs")
  export ANTHROPIC_IDENTITY_TOKEN_FILE="$dir/identity-token"
  write_identity_token() {
    curl -fsS -H "Authorization: Bearer $request_token" \
      "$request_url&audience=https://api.anthropic.com" \
      | jq -er .value > "$ANTHROPIC_IDENTITY_TOKEN_FILE.next"
    mv "$ANTHROPIC_IDENTITY_TOKEN_FILE.next" "$ANTHROPIC_IDENTITY_TOKEN_FILE"
  }
  write_identity_token
  (while sleep 240; do write_identity_token || true; done) &
  refresh=$!
  echo '{"version":"1.0","authentication":{"type":"oidc_federation"}}' > "$dir/configs/default.json"
  export ANTHROPIC_CONFIG_DIR="$dir" ANTHROPIC_PROFILE=default
fi

status=0
"$claude" -p "$(cat "$PROMPT")" \
  --model "$MODEL" \
  --max-turns "$MAX_TURNS" \
  --allowedTools Read Grep Glob "Bash(git log:*)" "Bash(git show:*)" "Bash(git diff:*)" "Bash(gh pr view:*)" \
  --json-schema "$(cat "$GITHUB_ACTION_PATH/schema.json")" \
  --output-format json < /dev/null > "$RESULT" || status=$?
[ -z "$refresh" ] || kill "$refresh" 2> /dev/null || true
exit "$status"
