#!/usr/bin/env bash
# install.sh <tool> {<runner-arch> <owner/repo>@<tag> <asset> sha256:<hex>}...
# Downloads the release asset pinned for $RUNNER_ARCH, checks its sha256, and
# prints the path of <tool>. {version} in <asset> is the tag after its last v.
set -euo pipefail

tool=$1
shift
while [ "$#" -ge 4 ]; do
  if [ "$1" = "$RUNNER_ARCH" ]; then
    repo=${2%@*} tag=${2#*@} sum=${4#sha256:}
    asset=${3//\{version\}/${tag##*v}}
    dir="$RUNNER_TEMP/$tool-$tag"
    mkdir -p "$dir"
    curl -fsSL --retry 3 -o "$dir/$asset" "https://github.com/$repo/releases/download/$tag/$asset"
    if ! printf '%s  %s\n' "$sum" "$dir/$asset" | shasum -a 256 -c --status; then
      echo "$tool: $asset does not match its pinned sha256" >&2
      exit 1
    fi
    tar -xzf "$dir/$asset" -C "$dir"
    bin="$(find "$dir" -type f -name "$tool" -print -quit)"
    [ -x "$bin" ] || { echo "$tool: no executable in $asset" >&2; exit 1; }
    echo "$tool: $repo $tag $asset sha256 verified" >&2
    echo "$bin"
    exit 0
  fi
  shift 4
done
echo "$tool: no pinned release for $RUNNER_OS $RUNNER_ARCH" >&2
exit 1
