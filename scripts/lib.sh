#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing file: $1"
}

require_value() {
  local actual=$1
  local expected=$2
  local label=$3
  [[ "$actual" == "$expected" ]] || \
    die "$label mismatch: expected $expected, got $actual"
}

require_config_y() {
  local config=$1
  local symbol=$2
  grep -Fqx -- "$symbol=y" "$config" || die "$symbol is not enabled"
}

require_config_absent() {
  local config=$1
  local pattern=$2
  if grep -Eq -- "$pattern" "$config"; then
    die "forbidden configuration matched: $pattern"
  fi
}

