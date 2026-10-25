# putdotio/.github

Reusable GitHub Actions workflows and composite actions for put.io
repositories. A workflow or action applies to a repository only once it
commits a caller. Reusable workflows must live in `.github/workflows/`, so each
team's workflows carry its name as a prefix; the actions in `.github/actions/`
are team-neutral.

The one community-health fallback is [`SECURITY.md`](SECURITY.md): GitHub
shows it for every put.io repository, public or private, that has no
`SECURITY.md` of its own.

Every push to `main` with a releasable Conventional Commit tags a release
([`release.yml`](.github/workflows/release.yml)). Callers pin a workflow or
action to that release's commit with the tag as the version comment, and
Renovate moves the pin. Removing an input, adding a required input, renaming
an output, or changing a default that alters caller behavior ships as a major.

## Renovate

[`renovate-config.json`](renovate-config.json) is the shared dependency-update
policy. The Renovate app runs only where a repository commits a config:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>putdotio/.github:renovate-config"]
}
```

## frontend-release-npm.yml

Publishes an npm package with semantic-release and npm trusted publishing. The
caller keeps its own verify job, workflow filename (npm's trusted publisher
checks it), `.releaserc.json`, and `release` Environment with the variable
`PUTIO_CI_APP_CLIENT_ID` and the secret `PUTIO_CI_APP_PRIVATE_KEY`.
The default plugins write `package.json` back to `main` as `putio-ci[bot]`, so
that App stays a bypass actor on the caller's default-branch ruleset. npm
trusted publishing supports GitHub-hosted runners only.

```yaml
release:
  if: github.event_name == 'push' && github.ref == 'refs/heads/main' && !contains(github.event.head_commit.message, '[skip ci]')
  needs: [verify]
  permissions:
    contents: read
    id-token: write
  uses: putdotio/.github/.github/workflows/frontend-release-npm.yml@<commit> # vX.Y.Z
  secrets:
    PUTIO_CI_APP_PRIVATE_KEY: ${{ secrets.PUTIO_CI_APP_PRIVATE_KEY }}
```

## actions/scan

[`actions/scan`](.github/actions/scan/action.yml) scans secrets and workflows
as the last steps of the caller's existing `verify` job, after its checkout:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event_name == 'pull_request' && github.ref || github.run_id }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  verify:
    steps:
      # checkout and the existing steps
      - if: ${{ !cancelled() }}
        uses: putdotio/.github/.github/actions/scan@<commit> # vX.Y.Z
```

It scans only on `push` and `workflow_dispatch`, so the caller's `verify`
workflow needs both triggers. Keep the per-run concurrency group: a shared push
group cancels a queued push run and leaves its range unscanned.

That group no longer serializes release, publish, or deploy jobs in the same
workflow. Give each a job-level `release-${{ github.repository }}-main` group
with `cancel-in-progress: false` and `queue: max`, and check out `github.sha`,
as [`frontend-release-npm.yml`](#frontend-release-npmyml) does. Without
`queue: max`, a late older release replaces a newer pending one, then skips
because `main` moved on.

- A repository on non-GitHub runner labels lists them in
  `.github/actionlint.yaml`.
- Dispatch once after a scanner upgrade; a dispatch scans full history.

## actions/links

[`actions/links`](.github/actions/links/action.yml) checks relative links and
heading anchors in tracked Markdown with lychee, as a step of the caller's
existing `verify` job on every event:

```yaml
- uses: putdotio/.github/.github/actions/links@<commit> # vX.Y.Z
```

It runs offline, so web links are not checked. Mark vendored paths
`linguist-vendored` in `.gitattributes`; a root `.lycheeignore` or
`lychee.toml` adds exceptions.

Both are steps rather than workflows: a separate job pays its own runner start
and checkout for seconds of work. The reasoning is in gh-setup's
[security baseline](https://github.com/uinaf/ffss/blob/main/skills/gh-setup/references/security-baseline.md)
and
[runner cost](https://github.com/uinaf/ffss/blob/main/skills/gh-setup/references/runner-cost.md).

## actions/beta-notes

[`actions/beta-notes`](.github/actions/beta-notes/action.yml) writes tester
notes for a beta build. Claude reads the pull requests and code changed since
a base build, usually the last store release, and returns short bullets, one
per line:

```yaml
permissions:
  contents: read
  pull-requests: read
  id-token: write # workload identity federation
steps:
  - uses: actions/checkout@<commit>
    with:
      fetch-depth: 0
      persist-credentials: false
  - id: notes
    uses: putdotio/.github/.github/actions/beta-notes@<commit> # vX.Y.Z
    with:
      app: put.io for Apple TV
      tag-pattern: apple-tv-v* # release tags
```

A Claude failure, an empty list, or a missing base build gives `fallback`; a
beta never waits on Claude. Set `max-length: 500` for Google Play.

The action authenticates through workload identity federation, so no key is
stored. Its federation IDs are input defaults, not organization variables:
none is a secret, and GitHub Free hides organization variables from private
repositories.

## Pinned versions

Each scanner and linter runs at one pinned version on every runner: an image
digest on Linux, a sha256-checked release archive on macOS.

Dependabot updates none of them
([caveats](https://docs.github.com/en/code-security/dependabot/ecosystems-supported-by-dependabot/supported-ecosystems-and-repositories#github-actions)),
so an upgrade moves every pin of the tool in one commit: the image tag and
digest, and the release tag and each macOS asset's sha256
(`gh release view <tag> -R <owner>/<repo> --json assets` lists them).
pyflakes publishes no release archives, so its pin is the commit its tag names
(`git ls-remote https://github.com/PyCQA/pyflakes 'refs/tags/<tag>^{}'`).
`mise run verify` fails when one tool's pins name different versions.

## Verify

```bash
pnpm install
mise run verify
```

`pnpm exec oxfmt '**/*.md'` fixes Markdown formatting. CI runs the same task
and both actions ([`verify.yml`](.github/workflows/verify.yml)).
