#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK_DIR=${1:?usage: prepare-manifest.sh WORK_DIR OFFICIAL_MANIFEST_OUT}
OFFICIAL_MANIFEST_OUT=${2:?usage: prepare-manifest.sh WORK_DIR OFFICIAL_MANIFEST_OUT}

# shellcheck source=lib.sh
source "$PROJECT_DIR/scripts/lib.sh"
# shellcheck source=/dev/null
source "$PROJECT_DIR/manifest.lock"

official_repo="$WORK_DIR/official-manifest-repo"
pinned_repo="$WORK_DIR/pinned-manifest-repo"
mkdir -p "$official_repo" "$pinned_repo"

git -C "$official_repo" init -q
bash "$PROJECT_DIR/scripts/pin-source.sh" \
  "$MANIFEST_REPO" "$official_repo" "$MANIFEST_COMMIT" official-manifest
require_file "$official_repo/$MANIFEST_FILE"
cp "$official_repo/$MANIFEST_FILE" "$OFFICIAL_MANIFEST_OUT"

cp "$official_repo/$MANIFEST_FILE" "$pinned_repo/$MANIFEST_FILE"
pinned_manifest="$pinned_repo/$MANIFEST_FILE"

sed -i -E \
  "/name=\"android_kernel_common_oneplus_sm8850\"/ s#revision=\"[^\"]+\"#revision=\"$COMMON_COMMIT\"#" \
  "$pinned_manifest"
sed -i -E \
  "/name=\"android_kernel_oneplus_sm8850\"/ s#revision=\"[^\"]+\"#revision=\"$SOC_COMMIT\"#" \
  "$pinned_manifest"
sed -i -E \
  "/name=\"android_kernel_modules_and_devicetree_oneplus_sm8850\"/ s#revision=\"[^\"]+\"#revision=\"$DEVICE_COMMIT\"#" \
  "$pinned_manifest"

# Several immutable CodeLinaro revisions retain upstream branch hints which have
# since been deleted. They are transport hints only; removing them makes repo
# fetch the locked commit IDs directly. Disable the manifest-wide sync-c hint for
# the same reason.
sed -i -E 's/ upstream="[^"]*"//g; s/ sync-c="true"/ sync-c="false"/g' \
  "$pinned_manifest"

require_value "$(grep -Fc "$COMMON_COMMIT" "$pinned_manifest")" 1 \
  'pinned Common manifest entry count'
require_value "$(grep -Fc "$SOC_COMMIT" "$pinned_manifest")" 1 \
  'pinned SoC manifest entry count'
require_value "$(grep -Fc "$DEVICE_COMMIT" "$pinned_manifest")" 1 \
  'pinned device manifest entry count'
if grep -Eq 'upstream=|sync-c="true"|revision="oneplus/' "$pinned_manifest"; then
  die 'generated manifest still contains a moving or stale revision hint'
fi

git -C "$pinned_repo" init -q -b main
git -C "$pinned_repo" add "$MANIFEST_FILE"
GIT_AUTHOR_NAME=oneplus15t-native \
GIT_AUTHOR_EMAIL=oneplus15t-native@users.noreply.github.com \
GIT_COMMITTER_NAME=oneplus15t-native \
GIT_COMMITTER_EMAIL=oneplus15t-native@users.noreply.github.com \
GIT_AUTHOR_DATE=2000-01-01T00:00:00Z \
GIT_COMMITTER_DATE=2000-01-01T00:00:00Z \
  git -C "$pinned_repo" commit -q -m 'Generate immutable OnePlus 15T manifest'

printf 'Prepared official manifest %s and immutable sync manifest %s\n' \
  "$MANIFEST_COMMIT" "$(git -C "$pinned_repo" rev-parse HEAD)"
