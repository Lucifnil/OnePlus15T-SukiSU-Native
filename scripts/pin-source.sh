#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# shellcheck source=lib.sh
source "$PROJECT_DIR/scripts/lib.sh"

repo_url=${1:?usage: pin-source.sh REPO_URL CHECKOUT_DIR COMMIT LABEL}
checkout_dir=${2:?usage: pin-source.sh REPO_URL CHECKOUT_DIR COMMIT LABEL}
commit=${3:?usage: pin-source.sh REPO_URL CHECKOUT_DIR COMMIT LABEL}
label=${4:?usage: pin-source.sh REPO_URL CHECKOUT_DIR COMMIT LABEL}

[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "$label commit is not a full SHA-1"
[[ -d "$checkout_dir/.git" ]] || die "$label is not a Git checkout: $checkout_dir"

git -C "$checkout_dir" -c protocol.version=2 fetch \
  --depth=1 --no-tags "$repo_url" "$commit"
git -C "$checkout_dir" checkout -q --detach FETCH_HEAD
require_value "$(git -C "$checkout_dir" rev-parse HEAD)" "$commit" "$label commit"
git -C "$checkout_dir" diff --exit-code --

printf 'Pinned %s at %s\n' "$label" "$commit"
