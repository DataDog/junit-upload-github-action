#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 vX.Y.Z" >&2
  exit 1
fi

version="$1"

if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected an exact datadog-ci release tag like v5.13.1, got '$version'" >&2
  exit 1
fi

ruby - "$version" <<'RUBY'
version = ARGV.fetch(0)

action_path = 'action.yaml'
action = File.read(action_path)
action_pattern = /(^  datadog-ci-version:\n(?:(?!^  [A-Za-z0-9_-]+:).*\n)*?^    default: )"v\d+\.\d+\.\d+"/
abort "Unable to find datadog-ci-version default in #{action_path}" unless action.match?(action_pattern)
File.write(action_path, action.sub(action_pattern) { "#{Regexp.last_match(1)}\"#{version}\"" })

readme_path = 'README.md'
readme = File.read(readme_path)
readme_pattern = /^(\| `datadog-ci-version` \|.*\| False\s+\| `)v\d+\.\d+\.\d+(`\s+\|)$/
abort "Unable to find datadog-ci-version default in #{readme_path}" unless readme.match?(readme_pattern)
File.write(readme_path, readme.sub(readme_pattern) { "#{Regexp.last_match(1)}#{version}#{Regexp.last_match(2)}" })
RUBY
