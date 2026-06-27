#!/usr/bin/env bash
# Stub utils.sh for unit tests — delegates to real utils.sh then overrides
# functions that require running pihole-FTL binary.

_utils_stub_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../advanced/Scripts/utils.sh
source "${_utils_stub_dir}/../../../advanced/Scripts/utils.sh"

# Override getFTLConfigValue to avoid requiring pihole-FTL binary at source time
getFTLConfigValue() { echo ""; }
