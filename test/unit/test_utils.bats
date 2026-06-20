#!/usr/bin/env bats
# Unit tests for advanced/Scripts/utils.sh
# Run with: bats test/unit/test_utils.bats

UTILS_SH="${BATS_TEST_DIRNAME}/../../advanced/Scripts/utils.sh"

setup() {
    # shellcheck source=advanced/Scripts/utils.sh
    source "${UTILS_SH}"
}

# ---------------------------------------------------------------------------
# Exit code constants
# ---------------------------------------------------------------------------

@test "EXIT_OK equals 0" {
    [ "${EXIT_OK}" -eq 0 ]
}

@test "EXIT_GENERAL_ERROR equals 1" {
    [ "${EXIT_GENERAL_ERROR}" -eq 1 ]
}

@test "EXIT_INVALID_USAGE equals 2" {
    [ "${EXIT_INVALID_USAGE}" -eq 2 ]
}

@test "EXIT_NETWORK_ERROR equals 3" {
    [ "${EXIT_NETWORK_ERROR}" -eq 3 ]
}

@test "EXIT_DB_ERROR equals 4" {
    [ "${EXIT_DB_ERROR}" -eq 4 ]
}

# ---------------------------------------------------------------------------
# pihole_log
# ---------------------------------------------------------------------------

@test "pihole_log INFO writes to stdout" {
    run bash -c "source '${UTILS_SH}'; pihole_log INFO 'hello world'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[INFO]"* ]]
    [[ "${output}" == *"hello world"* ]]
}

@test "pihole_log WARN writes to stderr" {
    run bash -c "source '${UTILS_SH}'; pihole_log WARN 'bad thing' 2>&1 1>/dev/null"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[WARN]"* ]]
    [[ "${output}" == *"bad thing"* ]]
}

@test "pihole_log ERROR writes to stderr" {
    run bash -c "source '${UTILS_SH}'; pihole_log ERROR 'fatal error' 2>&1 1>/dev/null"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[ERROR]"* ]]
    [[ "${output}" == *"fatal error"* ]]
}

@test "pihole_log INFO does not write to stderr" {
    run bash -c "source '${UTILS_SH}'; pihole_log INFO 'just info' 2>/dev/null"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"just info"* ]]
}

@test "pihole_log output includes a timestamp" {
    run bash -c "source '${UTILS_SH}'; pihole_log INFO 'ts test'"
    # Timestamp pattern: YYYY-MM-DD HH:MM:SS
    [[ "${output}" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]
}

# ---------------------------------------------------------------------------
# addOrEditKeyValPair
# ---------------------------------------------------------------------------

@test "addOrEditKeyValPair adds a new key" {
    local tmpfile
    tmpfile="$(mktemp)"
    source "${UTILS_SH}"
    addOrEditKeyValPair "${tmpfile}" "MY_KEY" "myvalue"
    grep -q "^MY_KEY=myvalue$" "${tmpfile}"
    rm -f "${tmpfile}"
}

@test "addOrEditKeyValPair replaces an existing key" {
    local tmpfile
    tmpfile="$(mktemp)"
    echo "MY_KEY=old" > "${tmpfile}"
    source "${UTILS_SH}"
    addOrEditKeyValPair "${tmpfile}" "MY_KEY" "new"
    grep -q "^MY_KEY=new$" "${tmpfile}"
    # Old value must not appear
    ! grep -q "old" "${tmpfile}"
    rm -f "${tmpfile}"
}

@test "addOrEditKeyValPair does not duplicate keys" {
    local tmpfile
    tmpfile="$(mktemp)"
    source "${UTILS_SH}"
    addOrEditKeyValPair "${tmpfile}" "DUP_KEY" "v1"
    addOrEditKeyValPair "${tmpfile}" "DUP_KEY" "v2"
    local count
    count="$(grep -c "^DUP_KEY=" "${tmpfile}")"
    [ "${count}" -eq 1 ]
    rm -f "${tmpfile}"
}

# ---------------------------------------------------------------------------
# getFTLPID
# ---------------------------------------------------------------------------

@test "getFTLPID returns -1 when PID file is absent" {
    run bash -c "source '${UTILS_SH}'; getFTLPID /nonexistent/path/pihole-FTL.pid"
    [ "${status}" -eq 0 ]
    [ "${output}" = "-1" ]
}

@test "getFTLPID returns -1 when PID file is empty" {
    local pidfile
    pidfile="$(mktemp)"
    run bash -c "source '${UTILS_SH}'; getFTLPID '${pidfile}'"
    [ "${status}" -eq 0 ]
    [ "${output}" = "-1" ]
    rm -f "${pidfile}"
}

@test "getFTLPID returns the numeric PID from file" {
    local pidfile
    pidfile="$(mktemp)"
    echo "12345" > "${pidfile}"
    run bash -c "source '${UTILS_SH}'; getFTLPID '${pidfile}'"
    [ "${status}" -eq 0 ]
    [ "${output}" = "12345" ]
    rm -f "${pidfile}"
}

@test "getFTLPID returns -1 when PID file contains non-numeric content" {
    local pidfile
    pidfile="$(mktemp)"
    echo "malicious; rm -rf /" > "${pidfile}"
    run bash -c "source '${UTILS_SH}'; getFTLPID '${pidfile}'"
    [ "${status}" -eq 0 ]
    [ "${output}" = "-1" ]
    rm -f "${pidfile}"
}

# ---------------------------------------------------------------------------
# loadVersionFile
# ---------------------------------------------------------------------------

@test "loadVersionFile assigns known keys" {
    local vfile
    vfile="$(mktemp)"
    echo "CORE_VERSION=6.0.0" > "${vfile}"
    run bash -c "source '${UTILS_SH}'; loadVersionFile '${vfile}'; echo \"\${CORE_VERSION}\""
    [ "${status}" -eq 0 ]
    [ "${output}" = "6.0.0" ]
    rm -f "${vfile}"
}

@test "loadVersionFile ignores unknown keys" {
    local vfile
    vfile="$(mktemp)"
    echo "EVIL_KEY=badvalue" > "${vfile}"
    run bash -c "source '${UTILS_SH}'; loadVersionFile '${vfile}'; echo \"\${EVIL_KEY:-unset}\""
    [ "${status}" -eq 0 ]
    [ "${output}" = "unset" ]
    rm -f "${vfile}"
}

@test "loadVersionFile rejects values with shell metacharacters" {
    local vfile
    vfile="$(mktemp)"
    echo 'CORE_VERSION=6.0.0; echo INJECTED' > "${vfile}"
    run bash -c "source '${UTILS_SH}'; loadVersionFile '${vfile}'; echo \"\${CORE_VERSION:-unset}\""
    [ "${status}" -eq 0 ]
    [ "${output}" = "unset" ]
    rm -f "${vfile}"
}

@test "loadVersionFile skips comment lines" {
    local vfile
    vfile="$(mktemp)"
    printf '# this is a comment\nCORE_VERSION=1.2.3\n' > "${vfile}"
    run bash -c "source '${UTILS_SH}'; loadVersionFile '${vfile}'; echo \"\${CORE_VERSION}\""
    [ "${status}" -eq 0 ]
    [ "${output}" = "1.2.3" ]
    rm -f "${vfile}"
}

@test "loadVersionFile returns 0 when file does not exist" {
    run bash -c "source '${UTILS_SH}'; loadVersionFile /nonexistent/versions"
    [ "${status}" -eq 0 ]
}
