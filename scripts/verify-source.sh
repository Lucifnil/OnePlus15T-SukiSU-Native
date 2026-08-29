#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SOURCE_DIR=${1:?usage: verify-source.sh SOURCE_DIR}

# shellcheck source=lib.sh
source "$PROJECT_DIR/scripts/lib.sh"
# shellcheck source=/dev/null
source "$PROJECT_DIR/manifest.lock"

require_value "$(git -C "$SOURCE_DIR/kernel_platform/common" rev-parse HEAD)" \
  "$COMMON_COMMIT" "common commit"
require_value "$(git -C "$SOURCE_DIR/kernel_platform/soc-repo" rev-parse HEAD)" \
  "$SOC_COMMIT" "SoC commit"
require_value "$(git -C "$SOURCE_DIR" rev-parse HEAD)" \
  "$DEVICE_COMMIT" "device/modules commit"

makefile="$SOURCE_DIR/kernel_platform/common/Makefile"
constants="$SOURCE_DIR/kernel_platform/common/build.config.constants"
canoe_config="$SOURCE_DIR/kernel_platform/soc-repo/build.config.msm.canoe"
common_build="$SOURCE_DIR/kernel_platform/common/BUILD.bazel"
soc_build="$SOURCE_DIR/kernel_platform/soc-repo/BUILD.bazel"

require_file "$makefile"
require_file "$constants"
require_file "$canoe_config"
require_file "$common_build"
require_file "$soc_build"

grep -Fqx 'VERSION = 6' "$makefile" || die 'kernel major version is not 6'
grep -Fqx 'PATCHLEVEL = 12' "$makefile" || die 'kernel patchlevel is not 12'
grep -Fqx 'SUBLEVEL = 38' "$makefile" || die 'kernel sublevel is not 38'
grep -Fqx "BRANCH=$EXPECTED_ANDROID_BRANCH" "$constants" || die 'Android branch mismatch'
grep -Fqx "KMI_GENERATION=$EXPECTED_KMI_GENERATION" "$constants" || die 'KMI generation mismatch'
grep -Fqx "CLANG_VERSION=$EXPECTED_CLANG_VERSION" "$constants" || die 'Clang revision mismatch'
grep -Fqx "RUSTC_VERSION=$EXPECTED_RUST_VERSION" "$constants" || die 'Rust revision mismatch'
grep -Fqx 'PAGE_SIZE=4096' "$canoe_config" || die 'canoe is not a 4K-page target'
grep -Fqx 'BOOT_IMAGE_HEADER_VERSION=4' "$canoe_config" || die 'unexpected boot header version'
grep -Fq 'name = "kernel_aarch64"' "$common_build" || die 'official Common GKI target missing'
grep -Fq 'build_setting_default = "//common:kernel_aarch64"' "$soc_build" || \
  die 'canoe perf does not use the official Common GKI target'

for tree in "$SOURCE_DIR/kernel_platform/common" "$SOURCE_DIR/kernel_platform/soc-repo"; do
  if git -C "$tree" grep -n -i -E \
    'kernelsu|sukisu|resukisu|susfs|tcp_brutal|drivers/rekernel|MQ_IOSCHED_ADIOS' -- \
    ':!Documentation/**' ':!*.txt'; then
    die "forbidden third-party kernel content detected in $tree"
  fi
done

git -C "$SOURCE_DIR/kernel_platform/common" diff --exit-code --
git -C "$SOURCE_DIR/kernel_platform/soc-repo" diff --exit-code --
git -C "$SOURCE_DIR" diff --exit-code --

printf 'Verified clean official OnePlus 15T source at common %s\n' "$COMMON_COMMIT"
