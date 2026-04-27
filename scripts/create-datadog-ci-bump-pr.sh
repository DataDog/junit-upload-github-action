#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/create-datadog-ci-bump-pr.sh [vX.Y.Z]

Checks the latest DataDog/datadog-ci release with gh, then opens a PR that bumps
the default datadog-ci-version when the release is newer than the current default.

Arguments:
  vX.Y.Z   Optional exact datadog-ci release tag to use instead of releases/latest.

Environment:
  BASE_BRANCH   Base branch for the PR. Defaults to main.
  BRANCH_NAME   Branch to create. Defaults to datadog-ci-bump/<version>.
  BUMP_LABEL    Label applied to the PR. Defaults to datadog-ci-version-bump.
  REMOTE        Git remote to push to. Defaults to origin.
  REPO          GitHub repo for gh commands. Defaults to gh repo view's repo.
  SEMVER_MINOR_LABEL
                Label applied for minor action releases. Defaults to semver-minor.
  SEMVER_PATCH_LABEL
                Label applied for patch action releases. Defaults to semver-patch.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 1
fi

for command in gh git ruby; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Missing required command: $command" >&2
    exit 1
  fi
done

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree must be clean before creating a bump PR." >&2
  exit 1
fi

gh auth status >/dev/null

base_branch="${BASE_BRANCH:-main}"
bump_label="${BUMP_LABEL:-datadog-ci-version-bump}"
remote="${REMOTE:-origin}"
repo="${REPO:-$(gh repo view --json nameWithOwner --jq '.nameWithOwner')}"
requested_version="${1:-}"
semver_minor_label="${SEMVER_MINOR_LABEL:-semver-minor}"
semver_patch_label="${SEMVER_PATCH_LABEL:-semver-patch}"

current_version=$(ruby -ryaml -e 'puts YAML.load_file("action.yaml").fetch("inputs").fetch("datadog-ci-version").fetch("default")')
if [[ -n "$requested_version" ]]; then
  latest_version="$requested_version"
else
  latest_version=$(gh api repos/DataDog/datadog-ci/releases/latest --jq '.tag_name')
fi

if [[ ! "$latest_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected an exact datadog-ci release tag like v5.13.1, got '$latest_version'" >&2
  exit 1
fi

is_exact_version() {
  [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

semver_parts() {
  local version="${1#v}"
  IFS=. read -r semver_major semver_minor semver_patch <<< "$version"
  echo "$semver_major $semver_minor $semver_patch"
}

bump_kind_for_datadog_ci_change() {
  local current="$1"
  local next="$2"

  if ! is_exact_version "$current"; then
    echo "minor"
    return 0
  fi

  local current_major current_minor current_patch next_major next_minor next_patch
  read -r current_major current_minor current_patch <<< "$(semver_parts "$current")"
  read -r next_major next_minor next_patch <<< "$(semver_parts "$next")"

  if (( next_major == current_major && next_minor == current_minor && next_patch > current_patch )); then
    echo "patch"
    return 0
  fi

  if (( next_major > current_major || (next_major == current_major && next_minor > current_minor) )); then
    echo "minor"
    return 0
  fi

  return 1
}

if ! release_bump_kind=$(bump_kind_for_datadog_ci_change "$current_version" "$latest_version"); then
  echo "No datadog-ci bump needed. Current default is $current_version; latest is $latest_version."
  exit 0
fi
if [[ "$release_bump_kind" == "minor" ]]; then
  release_label="$semver_minor_label"
else
  release_label="$semver_patch_label"
fi

branch_name="${BRANCH_NAME:-datadog-ci-bump/${latest_version#v}}"

existing_pr_url=$(gh pr list \
  --repo "$repo" \
  --head "$branch_name" \
  --state open \
  --json url \
  --jq '.[0].url // ""')
if [[ -n "$existing_pr_url" ]]; then
  echo "An open bump PR already exists: $existing_pr_url"
  exit 0
fi

if git show-ref --verify --quiet "refs/heads/$branch_name"; then
  echo "Local branch '$branch_name' already exists. Delete it or set BRANCH_NAME to another value." >&2
  exit 1
fi

git fetch "$remote" "$base_branch"
git checkout -b "$branch_name" FETCH_HEAD

scripts/bump-datadog-ci-version.sh "$latest_version"

git add action.yaml README.md
git commit -m "Bump datadog-ci to $latest_version"
git push -u "$remote" "$branch_name"

gh label create "$bump_label" \
  --repo "$repo" \
  --description "Marks PRs that bump the default datadog-ci version" \
  --color "1D76DB" \
  --force

gh label create "$release_label" \
  --repo "$repo" \
  --description "Requests a $release_bump_kind junit-upload-github-action release after merge" \
  --color "0E8A16" \
  --force

body_file=$(mktemp)
trap 'rm -f "$body_file"' EXIT
cat > "$body_file" <<EOF
## Summary

Bumps the default \`datadog-ci-version\` from \`$current_version\` to \`$latest_version\`.

## Release behavior

This PR is labeled \`$release_label\`, so the release helper will create a $release_bump_kind action release after merge.
EOF

gh pr create \
  --repo "$repo" \
  --base "$base_branch" \
  --head "$branch_name" \
  --title "Bump datadog-ci to $latest_version" \
  --body-file "$body_file" \
  --label "$bump_label" \
  --label "$release_label"
