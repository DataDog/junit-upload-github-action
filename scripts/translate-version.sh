#!/usr/bin/env bash
# Translates legacy npm semver syntax to GitHub release tag format
#
# This script provides backwards compatibility for users still using npm-style
# version specifiers (^, ~, >=, latest, etc.) by translating them to equivalent
# GitHub release tags that the install action understands.
#
# TODO: Remove this script in the next major version (v3.0.0)
#       Users should migrate to GitHub release tag syntax: v5, v5.10.0, etc.

set -euo pipefail

version="$1"

# Translate legacy npm semver syntax to GitHub release tags
case "$version" in
  latest)
    echo "::warning::datadog-ci-version 'latest' is deprecated. Please use 'v5' or '5' instead. This will use 'v5'." >&2
    version="v5"
    ;;
  ^*|~*|'>='*|'<='*|'>'*|'<'*|*.x)
    # Extract major version number from semver expressions
    # Handles: ^5.10.0, ~5.10.0, >=5.10.0, >5.10.0, <6.0.0, <=5.10.0, 5.x
    major=$(echo "$version" | grep -oE '[0-9]+' | head -1)
    if [[ -n "$major" ]]; then
      echo "::warning::npm semver syntax ('$version') is deprecated. Please use 'v${major}' or '${major}' instead. This will use 'v${major}'." >&2
      version="v${major}"
    else
      echo "::warning::Unable to parse version '$version'. Passing through as-is, but this may fail." >&2
    fi
    ;;
esac

echo "$version"
