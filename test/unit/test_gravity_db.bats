#!/usr/bin/env bats
# Unit tests for advanced/Scripts/database_migration/gravity-db.sh
# Run with: bats test/unit/test_gravity_db.bats

# shellcheck disable=SC1090,SC2034

GRAVITY_DB_SH="${BATS_TEST_DIRNAME}/../../advanced/Scripts/database_migration/gravity-db.sh"
HELPERS_DIR="${BATS_TEST_DIRNAME}/helpers"

setup() {
    # Put mock pihole-FTL first on PATH so it intercepts all calls
    export PATH="${HELPERS_DIR}:${PATH}"

    # Suppress colour/symbol variables used inside the script
    export INFO="[i]"
    export CROSS="[x]"
    export TICK="[✓]"
}

# ---------------------------------------------------------------------------
# upgrade_gravityDB — early-return when database file does not exist
# ---------------------------------------------------------------------------

@test "upgrade_gravityDB returns 0 when database file does not exist" {
    run bash -c "
        source '${GRAVITY_DB_SH}'
        upgrade_gravityDB /nonexistent/gravity.db
    "
    [ "${status}" -eq 0 ]
}

# ---------------------------------------------------------------------------
# run_migration — success path
# ---------------------------------------------------------------------------

@test "run_migration succeeds when SQL script runs without error" {
    local tmpdir
    tmpdir="$(mktemp -d)"

    # Create a minimal gravity.db with the info table so version queries work
    sqlite3 "${tmpdir}/gravity.db" \
        "CREATE TABLE info (property TEXT, value TEXT); INSERT INTO info VALUES ('version','1');"

    # Create a dummy SQL migration script that does nothing harmful
    mkdir -p "${tmpdir}/scripts"
    echo "SELECT 1;" > "${tmpdir}/scripts/1_to_2.sql"

    run bash -c "
        scriptPath='${tmpdir}/scripts'
        source '${GRAVITY_DB_SH}'
        run_migration 1 2 '${tmpdir}/gravity.db'
    "
    [ "${status}" -eq 0 ]
    rm -rf "${tmpdir}"
}

@test "run_migration prints INFO message on success" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    sqlite3 "${tmpdir}/gravity.db" "CREATE TABLE info (property TEXT, value TEXT);"
    mkdir -p "${tmpdir}/scripts"
    echo "SELECT 1;" > "${tmpdir}/scripts/2_to_3.sql"

    run bash -c "
        scriptPath='${tmpdir}/scripts'
        source '${GRAVITY_DB_SH}'
        run_migration 2 3 '${tmpdir}/gravity.db'
    "
    [[ "${output}" == *"Upgrading gravity database from version 2 to 3"* ]]
    rm -rf "${tmpdir}"
}

# ---------------------------------------------------------------------------
# run_migration — failure path
# ---------------------------------------------------------------------------

@test "run_migration returns non-zero when SQL script file is missing" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    sqlite3 "${tmpdir}/gravity.db" "CREATE TABLE info (property TEXT, value TEXT);"
    # Do NOT create the SQL script file — pihole-FTL mock will try to read it and fail

    run bash -c "
        scriptPath='${tmpdir}/missing'
        source '${GRAVITY_DB_SH}'
        run_migration 9 10 '${tmpdir}/gravity.db'
    "
    [ "${status}" -ne 0 ]
    rm -rf "${tmpdir}"
}

@test "run_migration prints error message to stderr when migration fails" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    sqlite3 "${tmpdir}/gravity.db" "CREATE TABLE info (property TEXT, value TEXT);"
    mkdir -p "${tmpdir}/scripts"
    # Invalid SQL causes sqlite3 to exit non-zero
    echo "THIS IS NOT VALID SQL;" > "${tmpdir}/scripts/5_to_6.sql"

    run bash -c "
        scriptPath='${tmpdir}/scripts'
        source '${GRAVITY_DB_SH}'
        run_migration 5 6 '${tmpdir}/gravity.db'
    " 2>&1
    [[ "${output}" == *"Migration from version 5 to 6 failed"* ]]
    rm -rf "${tmpdir}"
}

# ---------------------------------------------------------------------------
# scriptPath default value
# ---------------------------------------------------------------------------

@test "scriptPath defaults to the canonical migrations directory" {
    run bash -c "
        source '${GRAVITY_DB_SH}'
        echo \"\${scriptPath}\"
    "
    [ "${status}" -eq 0 ]
    [ "${output}" = "/etc/.pihole/advanced/Scripts/database_migration/gravity" ]
}

@test "scriptPath can be overridden before sourcing" {
    run bash -c "
        scriptPath='/tmp/custom_migrations'
        source '${GRAVITY_DB_SH}'
        echo \"\${scriptPath}\"
    "
    [ "${status}" -eq 0 ]
    [ "${output}" = "/tmp/custom_migrations" ]
}
