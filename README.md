# putdotio/.github

Reusable GitHub Actions workflows for put.io repositories. A workflow applies
to a repository only once it commits a caller. Reusable workflows must live in
`.github/workflows/`, so each team's files carry its name as a prefix.

The one community-health fallback is [`SECURITY.md`](SECURITY.md): GitHub
shows it for every put.io repository, public or private, that has no
`SECURITY.md` of its own.

Every push to `main` with a releasable Conventional Commit tags a release
([`release.yml`](.github/workflows/release.yml)). Callers pin a workflow to
that release's commit with the tag as the version comment, and Dependabot
moves the pin. Removing an input, adding a required input, renaming an output,
or changing a default that alters caller behavior ships as a major.

## frontend-release-npm.yml

Publishes an npm package with semantic-release and npm trusted publishing. The
caller keeps its own verify job, workflow filename (npm's trusted publisher
checks it), `.releaserc.json`, and `release` Environment with the variable
`PUTIO_CI_APP_CLIENT_ID` and the secret `PUTIO_CI_APP_PRIVATE_KEY`.
The secret is passed by name; the shared job binds to the same Environment and
reads the Environment's value. Existing callers can keep the legacy
`PUTIO_RELEASE_BOT_PRIVATE_KEY` input and `PUTIO_RELEASE_BOT_CLIENT_ID`
variable while moving to the new names. The default plugins write `package.json` back
to `main` as `putio-ci[bot]`, so that App stays a bypass actor on the
caller's default-branch ruleset. Vite+ resolves from the caller's
`package.json` pin. npm trusted publishing supports GitHub-hosted runners only.

Inputs, all optional: `runner`, `ref`, `node-version-file`,
`semantic-version`, `extra-plugins` (newline-separated, exact versions),
`build-command` and `working-directory` for packages that do not build in
`prepack`.

```yaml
release:
  if: github.event_name == 'push' && github.ref == 'refs/heads/main' && !contains(github.event.head_commit.message, '[skip ci]')
  needs: [verify]
  permissions:
    contents: read
    id-token: write
  uses: putdotio/.github/.github/workflows/frontend-release-npm.yml@<commit> # v1.0.1
  secrets:
    PUTIO_CI_APP_PRIVATE_KEY: ${{ secrets.PUTIO_CI_APP_PRIVATE_KEY }}
```

## frontend-scan.yml

Gitleaks, TruffleHog, Actionlint, and Zizmor from digest-pinned images. Pull
requests scan commits outside the base with Gitleaks and lint only when
`.github/`, action metadata, or scanner configuration changed; weekly and
manual runs scan full history and always lint. TruffleHog always scans full
history. Inputs: `runner` (private repositories may pass a Blacksmith label,
which also needs `.github/actionlint.yaml`) and `zizmor-args`. Scanner image
tags and digests are updated by hand.

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
    uses: putdotio/.github/.github/workflows/frontend-scan.yml@<commit> # v1.0.1
```

After `pnpm install`, `mise run verify` lints and audits the workflows and
checks Markdown formatting with oxfmt; `pnpm exec oxfmt '**/*.md'` fixes
findings. [Verify](.github/workflows/verify.yml) runs it on pull requests and
`main`, and the [scan caller](.github/workflows/scan.yml) runs the shared scan
on pull requests.
