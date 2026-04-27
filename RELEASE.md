# Release Process

This repository ships a composite GitHub Action. Releases are Git tags: immutable semver tags such as `v3.1.0`, plus a moving major tag such as `v3`.

## Requirements

The release scripts require the [GitHub CLI](https://cli.github.com/manual/) and an authenticated session:

```bash
gh auth login
gh auth status
```

Run release scripts from a clean working tree.

## Release labels

Every PR must have one of these labels:

- `semver-patch`: requests the next patch release
- `semver-minor`: requests the next minor release

If a release includes multiple merged PRs, `semver-minor` wins over `semver-patch`. Major releases are explicit: pass `--tag vX.0.0` to the release script.

## Bump datadog-ci

This repository provides a helper for the common case of bumping the default `datadog-ci-version`. It is not required for every `junit-upload-github-action` release; any merged PR with a `semver-patch` or `semver-minor` label can be released with `scripts/release-action.sh`.

To create a `datadog-ci-version` bump PR, run the helper from a clean working tree:

```bash
scripts/create-datadog-ci-bump-pr.sh
```

The script uses `gh` to check the latest `DataDog/datadog-ci` release. If that release is newer than the default in `action.yaml`, it creates a branch, updates `action.yaml` and `README.md`, pushes the branch, creates labels if needed, and opens a PR.

The PR gets:

- `datadog-ci-version-bump`
- `semver-patch` when `datadog-ci` only changed by patch
- `semver-minor` when `datadog-ci` changed by minor, or when moving from a floating default to the first pinned version

To test a specific version instead of the latest release:

```bash
scripts/create-datadog-ci-bump-pr.sh v5.14.0
```

Review and merge the PR normally.

## Release the action

Preview the release first:

```bash
scripts/release-action.sh --dry-run
```

The script fetches `main` and tags, finds merged PRs since the latest immutable action tag, reads their `semver-patch` and `semver-minor` labels, and chooses the next action tag. It releases `origin/main` by default, updates the moving major tag, and creates a GitHub Release with GitHub-generated release notes.

If the dry run looks right, publish the release:

```bash
scripts/release-action.sh
```

To release a specific commit on `main`:

```bash
scripts/release-action.sh --sha abc1234 --dry-run
scripts/release-action.sh --sha abc1234
```

To choose the tag manually:

```bash
scripts/release-action.sh --tag v3.2.1 --dry-run
scripts/release-action.sh --tag v3.2.1
```

If the requested tag is lower than the merged PR labels imply, for example a patch tag while an unreleased PR has `semver-minor`, the script fails. To publish that tag intentionally:

```bash
scripts/release-action.sh --tag v3.2.1 --allow-version-mismatch
```
