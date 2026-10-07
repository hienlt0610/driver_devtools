#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <package-version>" >&2
  echo "Example: $0 1.0.3+4" >&2
  exit 64
fi

release_version="$1"
semver_pattern='^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$'
if [[ ! "$release_version" =~ $semver_pattern ]]; then
  echo "Invalid version: $release_version" >&2
  echo 'Expected semantic version, for example 1.0.3 or 1.0.3+4.' >&2
  exit 64
fi

extension_version="${release_version%%+*}"
version_files=(
  "pubspec.yaml"
  "extension/devtools/config.yaml"
)

for version_file in "${version_files[@]}"; do
  if [[ ! -f "$version_file" ]] || ! grep -qE '^version:' "$version_file"; then
    echo "Missing version field in $version_file" >&2
    exit 1
  fi
done

RELEASE_VERSION="$release_version" perl -0pi -e \
  's/^version:\s*[^\n]+$/version: $ENV{RELEASE_VERSION}/m' pubspec.yaml
RELEASE_VERSION="$extension_version" perl -0pi -e \
  's/^version:\s*[^\n]+$/version: $ENV{RELEASE_VERSION}/m' \
  extension/devtools/config.yaml

printf 'Updated package version to %s\n' "$release_version"
printf 'Updated DevTools extension version to %s\n' "$extension_version"

exec dart run devtools_extensions build_and_copy \
  --source=. \
  --dest=extension/devtools
