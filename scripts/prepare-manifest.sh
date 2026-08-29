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

# Three historical test/module inputs in the published manifest have been
# removed from their CodeLinaro server and are not inputs to the Common GKI
# target. The published Clang and kernel build-tools snapshots are gone as
# well, so use Google's immutable official prebuilts at the paths Kleaf expects.
sed -i \
  '/name="kernel\/common-modules\/trusty"/d; /name="kernel_platform\/prebuilts\/asuite"/d; /name="kernel_platform\/tools\/tradefederation\/prebuilts"/d' \
  "$pinned_manifest"
sed -i \
  '/<remote fetch="https:\/\/github.com\/OnePlusOSS" name="origin"\/>/a\  <remote fetch="https://android.googlesource.com" name="aosp"/>' \
  "$pinned_manifest"
sed -i -E \
  "/name=\"kernel\/prebuilts\/build-tools\"/,/<\/project>/c\  <project remote=\"aosp\" name=\"kernel/prebuilts/build-tools\" path=\"kernel_platform/prebuilts/kernel-build-tools\" revision=\"$AOSP_KERNEL_BUILD_TOOLS_COMMIT\" groups=\"ddk\">\n      <linkfile dest=\"kernel_platform/build/prebuilts/kernel-build-tools\" src=\".\"/>\n    </project>" \
  "$pinned_manifest"
sed -i -E \
  "/name=\"kernelplatform\/prebuilts-master\/clang\/host\/linux-x86\"/c\  <project remote=\"aosp\" name=\"platform/prebuilts/clang/host/linux-x86\" path=\"kernel_platform/prebuilts/clang/host/linux-x86\" revision=\"$AOSP_CLANG_COMMIT\" groups=\"ddk\"/>" \
  "$pinned_manifest"

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
require_value "$(grep -Fc "$AOSP_CLANG_COMMIT" "$pinned_manifest")" 1 \
  'pinned AOSP Clang manifest entry count'
require_value "$(grep -Fc "$AOSP_KERNEL_BUILD_TOOLS_COMMIT" "$pinned_manifest")" 1 \
  'pinned AOSP kernel build-tools manifest entry count'
if grep -Eq 'upstream=|sync-c="true"|revision="oneplus/' "$pinned_manifest"; then
  die 'generated manifest still contains a moving or stale revision hint'
fi
if grep -Eq '4d7c778e792fbb56ced787158817ba1f17c68f3e|1af373e4210e3eacf056c56182140d3ef0a22379|3408234902a6e80b1ecda64a69c4e469a6216441|4ba19a61c7a0d63603e0d1c84eb2b610bff706a4|7cb95284aba215c2e1bbb70f545867f3d9295d58' \
  "$pinned_manifest"; then
  die 'generated manifest still contains an unavailable CodeLinaro revision'
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
