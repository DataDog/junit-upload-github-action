#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release-action.sh --tag vX.Y.Z [--sha COMMIT] [--dry-run]

Creates a generic action release from a commit on main. The script creates the
immutable release tag, updates the moving major tag, and creates a GitHub Release
using GitHub-generated release notes starting from the previous immutable tag.

Options:
  --tag TAG       Required immutable action tag to create, e.g. v3.2.0
  --sha COMMIT    Commit to release. Defaults to origin/main after fetch.
  --dry-run       Print the release that would be created.

Environment:
  BASE_BRANCH   Branch to inspect. Defaults to main.
  REMOTE        Git remote to fetch and push. Defaults to origin.
  REPO          GitHub repo for gh commands. Defaults to gh repo view's repo.
EOF
}

dry_run=false
requested_tag=""
requested_sha=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --tag)
      if [[ -n "$requested_tag" || -z "${2:-}" ]]; then
        usage >&2
        exit 1
      fi
      requested_tag="$2"
      shift 2
      ;;
    --sha)
      if [[ -n "$requested_sha" || -z "${2:-}" ]]; then
        usage >&2
        exit 1
      fi
      requested_sha="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$requested_tag" ]]; then
  echo "--tag is required" >&2
  usage >&2
  exit 1
fi

if [[ ! "$requested_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected --tag to be an immutable action tag like v3.2.0, got '$requested_tag'" >&2
  exit 1
fi

for command in gh git; do
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
remote="${REMOTE:-origin}"
repo="${REPO:-$(gh repo view --json nameWithOwner --jq '.nameWithOwner')}"

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

target_sha="${requested_sha:-$base_ref}"
target_sha=$(git rev-parse "$target_sha")

if ! git cat-file -e "${target_sha}^{commit}" 2>/dev/null; then
  echo "Commit '$target_sha' was not found locally." >&2
  exit 1
fi

if ! git merge-base --is-ancestor "$target_sha" "$base_ref"; then
  echo "Commit '$target_sha' is not in $remote/$base_branch history." >&2
  exit 1
fi

if git merge-base --is-ancestor "$target_sha" "$latest_tag"; then
  echo "Commit '$target_sha' is already included in latest action release $latest_tag." >&2
  exit 1
fi

if ! git merge-base --is-ancestor "$latest_tag" "$target_sha"; then
  echo "Commit '$target_sha' is not after latest action release $latest_tag." >&2
  exit 1
fi

semver_parts() {
  local version="${1#v}"
  IFS=. read -r semver_major semver_minor semver_patch <<< "$version"
  echo "$semver_major $semver_minor $semver_patch"
}

read -r latest_major latest_minor latest_patch <<< "$(semver_parts "$latest_tag")"
read -r requested_major requested_minor requested_patch <<< "$(semver_parts "$requested_tag")"

if (( requested_major < latest_major )) || \
   (( requested_major == latest_major && requested_minor < latest_minor )) || \
   (( requested_major == latest_major && requested_minor == latest_minor && requested_patch <= latest_patch )); then
  echo "Requested tag '$requested_tag' must be newer than latest immutable action release '$latest_tag'." >&2
  exit 1
fi

major_tag="v${requested_major}"

if git rev-parse --verify --quiet "refs/tags/$requested_tag" >/dev/null; then
  echo "Tag '$requested_tag' already exists locally." >&2
  exit 1
fi

if gh release view "$requested_tag" --repo "$repo" >/dev/null 2>&1; then
  echo "GitHub Release '$requested_tag' already exists." >&2
  exit 1
fi

echo "Latest action release tag: $latest_tag"
echo "Next action release tag: $requested_tag"
echo "Moving major tag: $major_tag"
echo "Release commit: $target_sha"

if [[ "$dry_run" == "true" ]]; then
  echo "Dry run only. No tags or GitHub Release were created."
  exit 0
fi

git tag "$requested_tag" "$target_sha"
git tag -f "$major_tag" "$target_sha"
git push "$remote" "refs/tags/$requested_tag"
git push --force "$remote" "refs/tags/$major_tag"

gh release create "$requested_tag" \
  --repo "$repo" \
  --title "$requested_tag" \
  --verify-tag \
  --generate-notes \
  --notes-start-tag "$latest_tag"
