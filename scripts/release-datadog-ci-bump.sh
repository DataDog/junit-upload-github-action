#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release-datadog-ci-bump.sh [--dry-run]

Finds the oldest merged datadog-ci bump PR on main that is not included in the
latest immutable action release tag. When one exists, creates the next patch
action tag, updates the moving major tag, and creates a GitHub Release.

Environment:
  BASE_BRANCH   Branch to inspect. Defaults to main.
  BUMP_LABEL    Label that marks release-triggering PRs. Defaults to datadog-ci-version-bump.
  REMOTE        Git remote to fetch and push. Defaults to origin.
  REPO          GitHub repo for gh commands. Defaults to gh repo view's repo.
  PR_LIMIT      Number of merged PRs to inspect. Defaults to 200.
EOF
}

dry_run=false
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
elif [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=true
elif [[ $# -gt 0 ]]; then
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
  echo "Working tree must be clean before creating a release." >&2
  exit 1
fi

gh auth status >/dev/null

base_branch="${BASE_BRANCH:-main}"
bump_label="${BUMP_LABEL:-datadog-ci-version-bump}"
remote="${REMOTE:-origin}"
repo="${REPO:-$(gh repo view --json nameWithOwner --jq '.nameWithOwner')}"
pr_limit="${PR_LIMIT:-200}"

git fetch --tags "$remote"
git fetch "$remote" "$base_branch"
base_ref="refs/remotes/$remote/$base_branch"

latest_tag=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1)
if [[ -z "$latest_tag" ]]; then
  echo "No existing immutable action release tag found." >&2
  exit 1
fi

if ! git merge-base --is-ancestor "$latest_tag" "$base_ref"; then
  echo "Latest immutable action tag $latest_tag is not in $remote/$base_branch history." >&2
  exit 1
fi

release_pr_number=""
release_pr_url=""
release_pr_merged_at=""
release_sha=""

while IFS=$'\t' read -r pr_number pr_url merged_at merge_sha; do
  [[ -z "$pr_number" ]] && continue
  [[ -z "$merge_sha" ]] && continue

  if ! git merge-base --is-ancestor "$merge_sha" "$base_ref"; then
    continue
  fi

  if git merge-base --is-ancestor "$merge_sha" "$latest_tag"; then
    continue
  fi

  if ! git merge-base --is-ancestor "$latest_tag" "$merge_sha"; then
    echo "Skipping PR #$pr_number because its merge commit is not after $latest_tag." >&2
    continue
  fi

  release_pr_number="$pr_number"
  release_pr_url="$pr_url"
  release_pr_merged_at="$merged_at"
  release_sha="$merge_sha"
  break
done < <(
  gh pr list \
    --repo "$repo" \
    --state merged \
    --base "$base_branch" \
    --label "$bump_label" \
    --limit "$pr_limit" \
    --json number,url,mergedAt,mergeCommit \
    --jq 'sort_by(.mergedAt) | .[] | [.number, .url, .mergedAt, .mergeCommit.oid] | @tsv'
)

if [[ -z "$release_sha" ]]; then
  echo "No unreleased merged PR with label '$bump_label' found on $remote/$base_branch."
  exit 0
fi

version="${latest_tag#v}"
IFS=. read -r major minor patch <<< "$version"
next_tag="v${major}.${minor}.$((patch + 1))"
major_tag="v${major}"

if git rev-parse --verify --quiet "refs/tags/$next_tag" >/dev/null; then
  echo "Next release tag $next_tag already exists locally." >&2
  exit 1
fi

if gh release view "$next_tag" --repo "$repo" >/dev/null 2>&1; then
  echo "GitHub Release $next_tag already exists." >&2
  exit 1
fi

datadog_ci_version=$(git show "$release_sha:action.yaml" | ruby -ryaml -e 'puts YAML.load($stdin.read).fetch("inputs").fetch("datadog-ci-version").fetch("default")')
if [[ ! "$datadog_ci_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected datadog-ci-version default to be an exact release tag at $release_sha, got '$datadog_ci_version'" >&2
  exit 1
fi

notes_file=$(mktemp)
trap 'rm -f "$notes_file"' EXIT
cat > "$notes_file" <<EOF
Updates the default \`datadog-ci-version\` to \`$datadog_ci_version\`.

Triggered by #$release_pr_number: $release_pr_url
Merged at: $release_pr_merged_at
EOF

echo "Latest action release tag: $latest_tag"
echo "Next action release tag: $next_tag"
echo "Moving major tag: $major_tag"
echo "Release commit: $release_sha"
echo "Release PR: #$release_pr_number"
echo "datadog-ci version: $datadog_ci_version"

if [[ "$dry_run" == "true" ]]; then
  echo "Dry run only. No tags or GitHub Release were created."
  exit 0
fi

git tag "$next_tag" "$release_sha"
git tag -f "$major_tag" "$release_sha"
git push "$remote" "refs/tags/$next_tag"
git push --force "$remote" "refs/tags/$major_tag"

gh release create "$next_tag" \
  --repo "$repo" \
  --target "$release_sha" \
  --title "$next_tag" \
  --notes-file "$notes_file"
