#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

exec dart run devtools_extensions build_and_copy \
  --source=. \
  --dest=extension/devtools
