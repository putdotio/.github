# Frontend shared workflows

Reusable workflows for repositories the put.io frontend team owns. The
[put.io frontend skill](https://github.com/putdotio/agent-skills/tree/main/skills/putio-frontend-dev)
lists those repositories and the delivery model these workflows implement.

## Release npm package

[`frontend-release-npm.yml`](../.github/workflows/frontend-release-npm.yml)
publishes an npm package with semantic-release and npm trusted publishing. The
caller keeps its own verify and scan jobs and its own workflow filename,
because npm's trusted publisher configuration checks the calling workflow's
name. The release bot's client id and private key live on the caller's
`release` Environment: the variable `PUTIO_RELEASE_BOT_CLIENT_ID` and the
secret `PUTIO_RELEASE_BOT_PRIVATE_KEY`. A caller cannot pass an Environment
secret through `workflow_call`; it passes the name, and the shared job, bound
to the same Environment, receives the Environment's value. npm trusted
publishing supports GitHub-hosted runners only, so the release job stays
GitHub-hosted in repositories that otherwise run on Blacksmith.

Inputs, all optional: `runner`, `ref` (defaults to the triggering commit),
`node-version-file`, `semantic-version`, `extra-plugins` (newline-separated,
exact versions; the default set covers analysis, notes, npm, `package.json`
writeback through `@semantic-release/git`, GitHub Release, and the Conventional
Commits preset), `build-command` with `working-directory` for packages whose
publish does not build itself through `prepack`. semantic-release runs at the
repository root and reads the caller's `.releaserc.json`. Vite+ is resolved
from the caller's `package.json` pin.

```yaml
release:
  if: github.event_name == 'push' && github.ref == 'refs/heads/main' && !contains(github.event.head_commit.message, '[skip ci]')
  needs: [verify]
  permissions:
    contents: read
    id-token: write
  uses: putdotio/.github/.github/workflows/frontend-release-npm.yml@<commit> # v1.0.0
  secrets:
    PUTIO_RELEASE_BOT_PRIVATE_KEY: ${{ secrets.PUTIO_RELEASE_BOT_PRIVATE_KEY }}
```

The writeback commit lands on `main` as `putio-releaser[bot]`, so the caller's
default-branch ruleset lists that App as a bypass actor.

## Scan

[`frontend-scan.yml`](../.github/workflows/frontend-scan.yml) runs Gitleaks,
TruffleHog, Actionlint, and Zizmor from digest-pinned images. Pull requests
scan only commits outside the PR base with Gitleaks; weekly and manual runs
scan full history. TruffleHog always scans full history because its range
traversal can stop before older PR commits when the base advances. Actionlint
and Zizmor allocate runners only when a PR changes `.github/`, action
metadata, Zizmor configuration, or ShellCheck configuration; weekly and manual
runs always lint. Required check names stay the same either way, because a
skipped job reports success.

```yaml
name: Scan

on:
  pull_request:
  schedule:
    - cron: "41 6 * * 1"
  workflow_dispatch:

permissions: {}

concurrency:
  group: scan-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  scan:
    permissions:
      contents: read
    uses: putdotio/.github/.github/workflows/frontend-scan.yml@<commit> # v1.0.0
```

The scan runs on GitHub-hosted Ubuntu ARM runners by default. Private
repositories may pass `runner` with a Blacksmith label; a caller declaring
that label also needs `.github/actionlint.yaml` listing it, or the Actionlint
job rejects its own workflows. `zizmor-args` passes extra zizmor flags for a
documented need, such as `--no-online-audits` when a workflow pins a private
first-party action whose tags the repository token cannot list.

Scanner image tags and digests are updated by hand; Dependabot does not track
images inside `run:` steps.
