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
Dependabot moves the pin. Removing an input, adding a required input, renaming
an output, or changing a default that alters caller behavior ships as a major.

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

It scans on `push` and `workflow_dispatch` and passes through every other
event, pull requests included, so the caller's `verify` workflow needs both
triggers. A concurrency group keeps one pending run and cancels it when a newer
run arrives, so pull-request runs share a group per ref and every other run
gets its own; a shared push group would cancel a queued push run and leave its
range unscanned. `!cancelled()` keeps the scan running after an earlier step
fails, so every pushed range is scanned. A finding fails the pushed commit's
`verify` run, and GitHub's failed-run email is the notification.

The per-run group no longer serializes release, publish, or deploy jobs in the
same workflow, so each takes a job-level `release-${{ github.repository }}-main`
group with `cancel-in-progress: false` and `queue: max` and checks out
`github.sha`, as [`frontend-release-npm.yml`](#frontend-release-npmyml) does.
Without `queue: max`, an older release whose verify finishes late replaces a
newer pending one and then skips because `main` has moved on, leaving the newer
commits unreleased until the next push.

- Gitleaks scans the pushed range of private repositories. Public repositories
  rely on GitHub secret scanning and push protection; `gitleaks: true` scans
  them too.
- Actionlint and Zizmor run when the range changes `.github/`, action
  metadata, Zizmor configuration, or ShellCheck configuration. `zizmor-args`
  adds arguments for documented needs, such as `--no-online-audits`. A
  repository on Blacksmith or other non-GitHub runner labels lists them in
  `.github/actionlint.yaml`.
- Manual dispatch, a new branch, or a previous head that is not an ancestor
  scans full history and always lints. Dispatch once after a scanner upgrade.
- The default shallow checkout with `persist-credentials: false` is enough:
  the action deepens it with `token` (default: the job token, which needs
  `contents: read`) until the previous head resolves. Zizmor's online audits
  use the same token.

Linux runners pull digest-pinned images; macOS runners download
sha256-pinned release binaries. [Pinned versions](#pinned-versions) lists
where each pin lives.

## actions/links

[`actions/links`](.github/actions/links/action.yml) checks relative links and
heading anchors in tracked Markdown with lychee, as a step of the caller's
existing `verify` job on every event:

```yaml
- uses: putdotio/.github/.github/actions/links@<commit> # vX.Y.Z
```

It runs offline with no network, so a result depends only on the commit; web
links are not checked. Root-relative links resolve from the repository root.
Untracked files and `node_modules/`, `vendor/`, `third_party/`, `Pods/`, and
`Carthage/` are skipped; mark other vendored paths `linguist-vendored` in
`.gitattributes`. A root `.lycheeignore` or `lychee.toml` adds exceptions.
lychee is pinned like the scanners ([Pinned versions](#pinned-versions)).

Both are steps rather than workflows because a separate job pays its own
runner start and checkout for seconds of work, and a pull-request scan repeats
the push scan every merge gets. Public repositories already block
provider-pattern secrets at push time, so Gitleaks scans private ones by
default, and the actions drop TruffleHog and the weekly schedule. The
reasoning and its sources are in gh-setup's
[security baseline](https://github.com/uinaf/ffss/blob/main/skills/gh-setup/references/security-baseline.md)
and
[runner cost](https://github.com/uinaf/ffss/blob/main/skills/gh-setup/references/runner-cost.md).

## Pinned versions

Each tool runs at one version on every runner. Linux runners pull its image
by digest. macOS runners download its release archive for the runner's
architecture and check the archive's sha256 before running it. `mise.toml`
pins the Actionlint and Zizmor that `mise run verify` runs locally and in CI.

| Tool       | Pins                                                                                                                                    |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Gitleaks   | [`actions/scan`](.github/actions/scan/action.yml), [`frontend-scan.yml`](.github/workflows/frontend-scan.yml)                           |
| Actionlint | [`actions/scan`](.github/actions/scan/action.yml), [`frontend-scan.yml`](.github/workflows/frontend-scan.yml), [`mise.toml`](mise.toml) |
| ShellCheck | [`actions/scan`](.github/actions/scan/action.yml) on macOS, at the release the Actionlint image bundles                                 |
| pyflakes   | [`actions/scan`](.github/actions/scan/action.yml) on macOS, at the release the Actionlint image bundles                                 |
| Zizmor     | [`actions/scan`](.github/actions/scan/action.yml), [`frontend-scan.yml`](.github/workflows/frontend-scan.yml), [`mise.toml`](mise.toml) |
| lychee     | [`actions/links`](.github/actions/links/action.yml), [`frontend-links.yml`](.github/workflows/frontend-links.yml)                       |

Dependabot updates none of them
([caveats](https://docs.github.com/en/code-security/dependabot/ecosystems-supported-by-dependabot/supported-ecosystems-and-repositories#github-actions)),
so an upgrade moves every pin of the tool in one commit: the image tag and
digest, and the release tag and each macOS asset's sha256
(`gh release view <tag> -R <owner>/<repo> --json assets` lists them).
pyflakes publishes no release archives, so its pin is the commit its tag names
(`git ls-remote https://github.com/PyCQA/pyflakes 'refs/tags/<tag>^{}'`).
`mise run verify` fails when one tool's pins name different versions.

## Deprecated: frontend-scan.yml and frontend-links.yml

[`frontend-scan.yml`](.github/workflows/frontend-scan.yml) (Gitleaks,
TruffleHog, Actionlint, and Zizmor as separate jobs on pull requests and a
weekly schedule) and [`frontend-links.yml`](.github/workflows/frontend-links.yml)
(the lychee check as its own job) still work, with their `runner` and
`zizmor-args` inputs, until the next major release removes them. To migrate,
delete the `Scan` and `Links` caller workflows and add
[`actions/scan`](#actionsscan) and [`actions/links`](#actionslinks) to
`verify`.

After `pnpm install`, `mise run verify` checks that each tool's pins agree,
lints and audits the workflows and actions, and checks Markdown formatting
with oxfmt; `pnpm exec oxfmt '**/*.md'`
fixes findings. [Verify](.github/workflows/verify.yml) runs it on pull
requests, `main`, and manual dispatch, then runs both actions from the same
commit; `gitleaks: true` scans this repository's own pushes.
