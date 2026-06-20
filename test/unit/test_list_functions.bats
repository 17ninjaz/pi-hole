#!/usr/bin/env bats
# Unit tests for the pure functions in advanced/Scripts/list.sh
# Run with: bats test/unit/test_list_functions.bats
#
# list.sh hardcodes PI_HOLE_SCRIPT_DIR="/opt/pihole" and sources utils.sh,
# api.sh, and COL_TABLE from that path.  We patch the path with sed into a
# temporary file, then source that file from within bash -c so that the
# BASH_SOURCE guard suppresses the main execution block.  Test code is written
# to a second temporary file to avoid premature variable expansion inside the
# double-quoted bash -c string.

# shellcheck disable=SC1090,SC2034

LIST_SH="${BATS_TEST_DIRNAME}/../../advanced/Scripts/list.sh"
HELPERS_DIR="${BATS_TEST_DIRNAME}/helpers"

# Source list.sh with patched paths, then execute the supplied code block.
# Two temp files are used:
#   patched_sh  – list.sh with /opt/pihole replaced by HELPERS_DIR
#   code_file   – the extra test code (written literally, no expansion here)
# Both are sourced from bash -c so that:
#   • BASH_SOURCE[0] != $0  → main execution block is skipped
#   • variables in code_file are expanded by the child bash, not by bats
_source_list_sh() {
    local extra_code="${1:-}"
    local patched_sh code_file
    patched_sh="$(mktemp /tmp/bats_list_patch_XXXXXX.sh)"
    code_file="$(mktemp /tmp/bats_list_code_XXXXXX.sh)"

    sed "s|PI_HOLE_SCRIPT_DIR=\"/opt/pihole\"|PI_HOLE_SCRIPT_DIR=\"${HELPERS_DIR}\"|g;
         s|colfile=\"/opt/pihole/COL_TABLE\"|colfile=\"${HELPERS_DIR}/COL_TABLE\"|g" \
        "${LIST_SH}" > "${patched_sh}"

    printf '%s\n' "${extra_code}" > "${code_file}"

    PATH="${HELPERS_DIR}:${PATH}" bash -c "source '${patched_sh}'; source '${code_file}'"
    local rc=$?
    rm -f "${patched_sh}" "${code_file}"
    return $rc
}

# ---------------------------------------------------------------------------
# CreateDomainList — plain domain
# ---------------------------------------------------------------------------

@test "CreateDomainList appends a plain domain to domList" {
    run _source_list_sh '
        wildcard=false
        domList=()
        CreateDomainList "example.com"
        echo "${domList[0]}"
    '
    [ "${status}" -eq 0 ]
    [ "${output}" = "example.com" ]
}

@test "CreateDomainList appends multiple domains" {
    run _source_list_sh '
        wildcard=false
        domList=()
        CreateDomainList "a.com"
        CreateDomainList "b.com"
        echo "${#domList[@]}"
    '
    [ "${status}" -eq 0 ]
    [ "${output}" = "2" ]
}

# ---------------------------------------------------------------------------
# CreateDomainList — wildcard mode
# ---------------------------------------------------------------------------

@test "CreateDomainList converts domain to regex in wildcard mode" {
    run _source_list_sh '
        wildcard=true
        domList=()
        CreateDomainList "example.com"
        echo "${domList[0]}"
    '
    [ "${status}" -eq 0 ]
    # Dots in the domain must be escaped; pattern anchored at start/end
    [[ "${output}" == *"example\\.com"* ]]
    [[ "${output}" == *"(\\.|^)"* ]]
}

@test "CreateDomainList wildcard regex is anchored with dollar sign" {
    run _source_list_sh '
        wildcard=true
        domList=()
        CreateDomainList "ads.example.com"
        echo "${domList[0]}"
    '
    [ "${status}" -eq 0 ]
    [[ "${output}" == *'$' ]]
}

# ---------------------------------------------------------------------------
# GetComment — valid comments
# ---------------------------------------------------------------------------

@test "GetComment accepts a simple alphanumeric comment" {
    run _source_list_sh '
        comment=""
        GetComment "my comment 123"
        echo "${comment}"
    '
    [ "${status}" -eq 0 ]
    [ "${output}" = "my comment 123" ]
}

@test "GetComment accepts comments with allowed special characters" {
    run _source_list_sh '
        comment=""
        GetComment "test_comment-v1.0/ok #all:good,right"
        echo "${comment}"
    '
    [ "${status}" -eq 0 ]
    [ "${output}" = "test_comment-v1.0/ok #all:good,right" ]
}

# ---------------------------------------------------------------------------
# GetComment — invalid comments (should exit 1)
# ---------------------------------------------------------------------------

@test "GetComment rejects a comment with shell metacharacters" {
    run _source_list_sh '
        GetComment "bad; rm -rf /"
        echo "should not reach here"
    '
    [ "${status}" -eq 1 ]
    [[ "${output}" != *"should not reach here"* ]]
}

@test "GetComment rejects a comment containing percent sign" {
    run _source_list_sh '
        GetComment "50% off"
        echo "should not reach here"
    '
    [ "${status}" -eq 1 ]
}

@test "GetComment rejects a comment containing exclamation mark" {
    run _source_list_sh '
        GetComment "hello!"
        echo "should not reach here"
    '
    [ "${status}" -eq 1 ]
}
