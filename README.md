# putdotio/.github

Shared GitHub Actions workflows for put.io repositories, grouped by owning team.

- [frontend](frontend/README.md): the npm release and scan workflows the
  frontend team's repositories call.

Reusable workflows must live in `.github/workflows/`, so each team's files carry
its name as a prefix (`frontend-*.yml`) and its documentation lives in the
team folder. This repository carries no community-health fallbacks; each
repository keeps its own `SECURITY.md`, `CONTRIBUTING.md`, and templates.

Every push to `main` that carries a releasable Conventional Commit tags a
release ([`release.yml`](.github/workflows/release.yml)). Callers pin a
workflow to that release's commit with the tag as the version comment, and
Dependabot moves the pin:

```yaml
uses: putdotio/.github/.github/workflows/frontend-scan.yml@<commit> # v1.0.0
```

Removing an input, adding a required input, renaming an output, or changing a
default that alters caller behavior is a breaking change and ships as a major
(`feat!:` or a `BREAKING CHANGE` footer). This README describes `main`; read
the tagged commit for the contract a given pin carries.

Run `mise run verify` before opening a pull request. The repository's own
[scan caller](.github/workflows/scan.yml) runs the shared scan at the pull
request's merge commit.
