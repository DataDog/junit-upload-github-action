#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release-datadog-ci-bump.sh [--dry-run] [--pr NUMBER | --sha COMMIT]

Finds the latest merged datadog-ci bump PR on main that is not included in the
latest immutable action release tag. When one exists, creates the next patch
action tag, updates the moving major tag, and creates a GitHub Release. If older
unreleased bump PRs exist, the script warns and releases only the latest change.

Options:
  --dry-run      Print the release that would be created.
  --pr NUMBER    Release a specific merged bump PR instead of the latest one.
  --sha COMMIT   Release a specific commit on main instead of finding a PR.

Environment:
  BASE_BRANCH   Branch to inspect. Defaults to main.
  BUMP_LABEL    Label that marks release-triggering PRs. Defaults to datadog-ci-version-bump.
  REMOTE        Git remote to fetch and push. Defaults to origin.
  REPO          GitHub repo for gh commands. Defaults to gh repo view's repo.
  PR_LIMIT      Number of merged PRs to inspect. Defaults to 200.
EOF
}

dry_run=false
requested_pr=""
requested_sha=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    --pr)
      if [[ -n "$requested_sha" || -n "$requested_pr" || -z "${2:-}" ]]; then
        usage >&2
        exit 1
      fi
      requested_pr="$2"
      shift 2
      ;;
    --sha)
      if [[ -n "$requested_pr" || -n "$requested_sha" || -z "${2:-}" ]]; then
        usage >&2
        exit 1
      fi
      requested_sha="$2"
      shift 2
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$requested_pr" && ! "$requested_pr" =~ ^[0-9]+$ ]]; then
  echo "--pr expects a numeric pull request number, got '$requested_pr'" >&2
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
unreleased_count=0

validate_release_sha() {
  local sha="$1"

  if ! git cat-file -e "${sha}^{commit}" 2>/dev/null; then
    echo "Commit '$sha' was not found locally." >&2
    return 1
  fi

  if ! git merge-base --is-ancestor "$sha" "$base_ref"; then
    echo "Commit '$sha' is not in $remote/$base_branch history." >&2
    return 1
  fi

  if git merge-base --is-ancestor "$sha" "$latest_tag"; then
    echo "Commit '$sha' is already included in latest action release $latest_tag." >&2
    return 1
  fi

  if ! git merge-base --is-ancestor "$latest_tag" "$sha"; then
    echo "Commit '$sha' is not after latest action release $latest_tag." >&2
    return 1
  fi
}

if [[ -n "$requested_sha" ]]; then
  release_sha=$(git rev-parse "$requested_sha")
  validate_release_sha "$release_sha"
elif [[ -n "$requested_pr" ]]; then
  pr_data=$(gh pr view "$requested_pr" \
    --repo "$repo" \
    --json number,url,mergedAt,mergeCommit,baseRefName,labels,state \
    --jq '
      if .state != "MERGED" then
        error("PR #\(.number) is not merged")
      elif .baseRefName != "'"$base_branch"'" then
        error("PR #\(.number) targets \(.baseRefName), not '"$base_branch"'")
      elif ([.labels[].name] | index("'"$bump_label"'") | not) then
        error("PR #\(.number) does not have label '"$bump_label"'")
      else
        [.number, .url, .mergedAt, .mergeCommit.oid] | @tsv
      end
    ')
  IFS=$'\t' read -r release_pr_number release_pr_url release_pr_merged_at release_sha <<< "$pr_data"
  validate_release_sha "$release_sha"
else
  while IFS=$'\t' read -r pr_number pr_url merged_at merge_sha; do
    [[ -z "$pr_number" ]] && continue
    [[ -z "$merge_sha" ]] && continue

    if ! validate_release_sha "$merge_sha" 2>/dev/null; then
      continue
    fi

    unreleased_count=$((unreleased_count + 1))
    release_pr_number="$pr_number"
    release_pr_url="$pr_url"
    release_pr_merged_at="$merged_at"
    release_sha="$merge_sha"
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

  if (( unreleased_count > 1 )); then
    echo "Warning: found $unreleased_count unreleased merged PRs with label '$bump_label'." >&2
    echo "This script will release only the latest one, #$release_pr_number." >&2
    echo "To release an older merge commit separately, stop and rerun with --pr NUMBER or --sha COMMIT before releasing the latest one." >&2
  fi
fi

if [[ -z "$release_sha" ]]; then
  echo "No unreleased merged PR with label '$bump_label' found on $remote/$base_branch."
  exit 0
fi

if [[ -n "$release_pr_number" ]]; then
  release_source="#$release_pr_number: $release_pr_url"
else
  release_source="$release_sha"
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

Triggered by $release_source
EOF
if [[ -n "$release_pr_merged_at" ]]; then
  echo "Merged at: $release_pr_merged_at" >> "$notes_file"
fi

echo "Latest action release tag: $latest_tag"
echo "Next action release tag: $next_tag"
echo "Moving major tag: $major_tag"
echo "Release commit: $release_sha"
if [[ -n "$release_pr_number" ]]; then
  echo "Release PR: #$release_pr_number"
fi
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
