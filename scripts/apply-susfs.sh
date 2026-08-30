#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
COMMON_DIR=${1:?usage: apply-susfs.sh COMMON_DIR KSU_DIR SUSFS_DIR}
KSU_DIR=${2:?usage: apply-susfs.sh COMMON_DIR KSU_DIR SUSFS_DIR}
SUSFS_DIR=${3:?usage: apply-susfs.sh COMMON_DIR KSU_DIR SUSFS_DIR}

# shellcheck source=/dev/null
source "$PROJECT_DIR/manifest.lock"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_blob() {
  local path=$1 expected=$2 actual
  actual=$(git -C "$SUSFS_DIR" rev-parse "$SUSFS_COMMIT:$path")
  [[ "$actual" == "$expected" ]] || \
    die "unexpected SUSFS blob for $path: $actual"
}

[[ "$(git -C "$COMMON_DIR" rev-parse HEAD)" == "$COMMON_COMMIT" ]] || \
  die 'Common source is not at the pinned OnePlus commit'
[[ "$(git -C "$KSU_DIR" rev-parse HEAD)" == "$SUKISU_COMMIT" ]] || \
  die 'SukiSU source is not at the pinned stable commit'
[[ "$(git -C "$SUSFS_DIR" rev-parse HEAD)" == "$SUSFS_COMMIT" ]] || \
  die 'SUSFS source is not at the pinned compatibility commit'

require_blob "$SUSFS_KERNEL_PATCH" "$SUSFS_KERNEL_PATCH_BLOB"
require_blob "$SUSFS_KSU_PATCH" "$SUSFS_KSU_PATCH_BLOB"
require_blob "$SUSFS_SOURCE" "$SUSFS_SOURCE_BLOB"
require_blob "$SUSFS_HEADER" "$SUSFS_HEADER_BLOB"
require_blob "$SUSFS_DEF_HEADER" "$SUSFS_DEF_HEADER_BLOB"

kernel_patch=$(mktemp)
ksu_patch=$(mktemp)
susfs_source=$(mktemp)
susfs_header=$(mktemp)
susfs_def_header=$(mktemp)
filtered_ksu_patch=$(mktemp)
cleanup() {
  rm -f "$kernel_patch" "$ksu_patch" "$susfs_source" "$susfs_header" \
    "$susfs_def_header" "$filtered_ksu_patch"
}
trap cleanup EXIT

# Materialize canonical Git blobs rather than a platform-dependent checkout;
# this also prevents core.autocrlf from changing official patch input.
git -C "$SUSFS_DIR" show "$SUSFS_COMMIT:$SUSFS_KERNEL_PATCH" > "$kernel_patch"
git -C "$SUSFS_DIR" show "$SUSFS_COMMIT:$SUSFS_KSU_PATCH" > "$ksu_patch"
git -C "$SUSFS_DIR" show "$SUSFS_COMMIT:$SUSFS_SOURCE" > "$susfs_source"
git -C "$SUSFS_DIR" show "$SUSFS_COMMIT:$SUSFS_HEADER" > "$susfs_header"
git -C "$SUSFS_DIR" show "$SUSFS_COMMIT:$SUSFS_DEF_HEADER" > \
  "$susfs_def_header"

grep -Fqx "#define SUSFS_VERSION \"v$SUSFS_VERSION\"" \
  "$susfs_header" || die 'unexpected SUSFS version header'

cp "$susfs_source" "$COMMON_DIR/fs/susfs.c"
cp "$susfs_header" "$COMMON_DIR/include/linux/susfs.h"
cp "$susfs_def_header" "$COMMON_DIR/include/linux/susfs_def.h"

# GNU patch is intentional here: the official SUSFS patches target upstream
# GKI/KernelSU and require bounded context offsets on the pinned OnePlus and
# SukiSU trees. Reject files and backup artifacts are forbidden below.
patch --batch --forward --fuzz=2 --no-backup-if-mismatch \
  -d "$COMMON_DIR" -p1 < "$kernel_patch"

awk '
  /^diff --git / {
    skip = ($0 ~ /^diff --git a\/kernel\/core\/init.c /)
  }
  !skip { print }
' "$ksu_patch" > "$filtered_ksu_patch"
grep -Fq 'diff --git a/kernel/Kconfig b/kernel/Kconfig' "$filtered_ksu_patch"
! grep -Fq 'diff --git a/kernel/core/init.c b/kernel/core/init.c' \
  "$filtered_ksu_patch"
patch --batch --forward --fuzz=2 --no-backup-if-mismatch \
  -d "$KSU_DIR" -p1 < "$filtered_ksu_patch"

adapt_patch="$PROJECT_DIR/$SUSFS_SUKISU_ADAPT_PATCH"
log_patch="$PROJECT_DIR/$SUSFS_DISABLE_LOG_PATCH"
selinux_wrapper_patch="$PROJECT_DIR/$SUSFS_SELINUX_WRAPPER_PATCH"
[[ "$(sha256sum "$adapt_patch" | awk '{print $1}')" == \
  "$SUSFS_SUKISU_ADAPT_PATCH_SHA256" ]] || \
  die 'SukiSU SUSFS adaptation patch checksum mismatch'
[[ "$(sha256sum "$log_patch" | awk '{print $1}')" == \
  "$SUSFS_DISABLE_LOG_PATCH_SHA256" ]] || \
  die 'SUSFS log policy patch checksum mismatch'
[[ "$(sha256sum "$selinux_wrapper_patch" | awk '{print $1}')" == \
  "$SUSFS_SELINUX_WRAPPER_PATCH_SHA256" ]] || \
  die 'SUSFS SELinux wrapper patch checksum mismatch'
git -C "$KSU_DIR" apply --check "$adapt_patch"
git -C "$KSU_DIR" apply --whitespace=error-all "$adapt_patch"
git -C "$KSU_DIR" apply --check "$log_patch"
git -C "$KSU_DIR" apply --whitespace=error-all "$log_patch"
git -C "$KSU_DIR" apply --check "$selinux_wrapper_patch"
git -C "$KSU_DIR" apply --whitespace=error-all "$selinux_wrapper_patch"

# v2.1.0's official patch contains a few harmless trailing blanks. Normalize
# only files changed by that immutable patch so CI can enforce diff hygiene.
while IFS= read -r path; do
  sed -i 's/[[:space:]]\+$//' "$COMMON_DIR/$path"
done < <(git -C "$COMMON_DIR" diff --name-only --diff-filter=AM)
sed -i 's/[[:space:]]\+$//' "$COMMON_DIR/fs/susfs.c" \
  "$COMMON_DIR/include/linux/susfs.h" \
  "$COMMON_DIR/include/linux/susfs_def.h"
while IFS= read -r path; do
  sed -i 's/[[:space:]]\+$//' "$KSU_DIR/$path"
done < <(git -C "$KSU_DIR" diff --name-only --diff-filter=AM)
sed -i 's/^[[:space:]]*just disable this feature/\t  just disable this feature/' \
  "$KSU_DIR/kernel/Kconfig"

if find "$COMMON_DIR" "$KSU_DIR" -type f \
    \( -name '*.rej' -o -name '*.orig' \) -print -quit | grep -q .; then
  die 'SUSFS integration left patch reject or backup files'
fi

git -C "$COMMON_DIR" diff --check
git -C "$KSU_DIR" diff --check
grep -Fqx 'obj-$(CONFIG_KSU_SUSFS) += susfs.o' "$COMMON_DIR/fs/Makefile"
grep -Fqx 'config KSU_SUSFS' "$KSU_DIR/kernel/Kconfig"
grep -A5 '^config KSU_SUSFS_ENABLE_LOG$' "$KSU_DIR/kernel/Kconfig" | \
  grep -Fqx $'\tdefault n'
grep -Fq 'susfs_init();' "$KSU_DIR/kernel/core/init.c"
! grep -Fq 'syscall_hook_manager_init' "$KSU_DIR/kernel/core/init.c"
! grep -Fq 'feature/uts_spoof.o' "$KSU_DIR/kernel/Kbuild"

printf 'Applied pinned SUSFS v%s to official Common and SukiSU v%s\n' \
  "$SUSFS_VERSION" "${SUKISU_TAG#v}"
