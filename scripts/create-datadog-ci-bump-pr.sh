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

version_gt() {
  local left="${1#v}"
  local right="${2#v}"
  local left_major left_minor left_patch right_major right_minor right_patch

  IFS=. read -r left_major left_minor left_patch <<< "$left"
  IFS=. read -r right_major right_minor right_patch <<< "$right"

  (( left_major > right_major )) && return 0
  (( left_major < right_major )) && return 1
  (( left_minor > right_minor )) && return 0
  (( left_minor < right_minor )) && return 1
  (( left_patch > right_patch ))
}

if ! version_gt "$latest_version" "$current_version"; then
  echo "No datadog-ci bump needed. Current default is $current_version; latest is $latest_version."
  exit 0
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
  --description "Triggers a junit-upload-github-action release after merge" \
  --color "1D76DB" \
  --force

body_file=$(mktemp)
trap 'rm -f "$body_file"' EXIT
cat > "$body_file" <<EOF
## Summary

Bumps the default \`datadog-ci-version\` from \`$current_version\` to \`$latest_version\`.

## Release behavior

Merging this PR with the \`$bump_label\` label will trigger the release workflow. That workflow creates the next immutable action tag, moves the major action tag, and creates a GitHub Release.
EOF

gh pr create \
  --repo "$repo" \
  --base "$base_branch" \
  --head "$branch_name" \
  --title "Bump datadog-ci to $latest_version" \
  --body-file "$body_file" \
  --label "$bump_label"
