# Release Process

This repository ships a composite GitHub Action. Releases are Git tags: immutable semver tags such as `v3.0.1`, plus a moving major tag such as `v3`.

## Bump datadog-ci

Run the bump helper from a clean working tree:

```bash
scripts/create-datadog-ci-bump-pr.sh
```

The script uses `gh` to check the latest `DataDog/datadog-ci` release. If that release is newer than the default in `action.yaml`, it creates a branch, updates `action.yaml` and `README.md`, pushes the branch, creates the `datadog-ci-version-bump` label if needed, and opens a PR with that label.

To test a specific version instead of the latest release:

```bash
scripts/create-datadog-ci-bump-pr.sh v5.14.0
```

Review and merge the PR normally.

## Release the action

After a `datadog-ci-version-bump` PR is merged, run:

```bash
scripts/release-datadog-ci-bump.sh
```

The script fetches `main` and tags, finds the latest merged PR with the `datadog-ci-version-bump` label that is on `main` but not included in the latest immutable action tag, and releases that merge commit. A release creates the next patch tag, updates the moving major tag, and creates a GitHub Release.

Preview the release without creating tags or a GitHub Release:

```bash
scripts/release-datadog-ci-bump.sh --dry-run
```

If multiple bump PRs were merged without releases, the script warns and releases only the latest one. To intentionally release an older merge commit separately, stop and pass a specific PR number or commit SHA before releasing the latest one:

```bash
scripts/release-datadog-ci-bump.sh --pr 123
scripts/release-datadog-ci-bump.sh --sha abc1234
```
