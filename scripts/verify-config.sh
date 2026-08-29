#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG=${1:?usage: verify-config.sh CONFIG}

# shellcheck source=lib.sh
source "$PROJECT_DIR/scripts/lib.sh"
require_file "$CONFIG"

require_config_y "$CONFIG" CONFIG_ARM64_4K_PAGES
require_config_y "$CONFIG" CONFIG_CFI_CLANG
require_config_y "$CONFIG" CONFIG_MODVERSIONS
require_config_y "$CONFIG" CONFIG_MODULE_SCMVERSION
require_config_y "$CONFIG" CONFIG_MODULE_SIG_PROTECT
require_config_y "$CONFIG" CONFIG_TRIM_UNUSED_KSYMS

require_config_absent "$CONFIG" '^CONFIG_ARM64_(16K|64K)_PAGES=y$'
require_config_absent "$CONFIG" '^CONFIG_(KSU|KPM|KSU_SUSFS)(=|_)'
require_config_absent "$CONFIG" '^CONFIG_MQ_IOSCHED_ADIOS='
require_config_absent "$CONFIG" '^CONFIG_REKERNEL='
require_config_absent "$CONFIG" '^CONFIG_TCP_CONG_BRUTAL='

printf 'Verified official 4K GKI configuration without Root or third-party features\n'

