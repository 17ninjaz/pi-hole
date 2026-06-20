#!/usr/bin/env bash


# Pi-hole: A black hole for Internet advertisements
# (c) 2019 Pi-hole, LLC (https://pi-hole.net)
# Network-wide ad blocking via your own hardware.
#
# Updates gravity.db database
#
# This file is copyright under the latest version of the EUPL.
# Please see LICENSE file for your rights under this license.

readonly scriptPath="/etc/.pihole/advanced/Scripts/database_migration/gravity"

# Run a single gravity migration SQL script and abort on failure.
# Usage: run_migration <from_version> <to_version> <database>
run_migration() {
    local from_ver="${1}" to_ver="${2}" database="${3}"
    local sql_script="${scriptPath}/${from_ver}_to_${to_ver}.sql"
    echo -e "  ${INFO} Upgrading gravity database from version ${from_ver} to ${to_ver}"
    if ! pihole-FTL sqlite3 -ni "${database}" < "${sql_script}"; then
        echo -e "  ${CROSS} Migration from version ${from_ver} to ${to_ver} failed." >&2
        echo -e "  ${CROSS} The gravity database at '${database}' may be in an inconsistent state." >&2
        echo -e "  ${INFO} Restore from a backup in $(dirname -- "${database}")/gravity_backups/ and retry." >&2
        return 1
    fi
}

upgrade_gravityDB(){
    local database version
    database="${1}"

    # Exit early if the database does not exist (e.g. in CI tests)
    if [[ ! -f "${database}" ]]; then
        return
    fi

    # Get database version
    version="$(pihole-FTL sqlite3 -ni "${database}" "SELECT \"value\" FROM \"info\" WHERE \"property\" = 'version';")"

    if [[ "$version" == "1" ]]; then
        # This migration script upgraded the gravity.db file by
        # adding the domain_audit table. It is now a no-op
        run_migration 1 2 "${database}" || return 1
        version=2
    fi
    if [[ "$version" == "2" ]]; then
        # This migration script upgrades the gravity.db file by
        # renaming the regex table to regex_blacklist, and
        # creating a new regex_whitelist table + corresponding linking table and views
        run_migration 2 3 "${database}" || return 1
        version=3
    fi
    if [[ "$version" == "3" ]]; then
        # This migration script unifies the formally separated domain
        # lists into a single table with a UNIQUE domain constraint
        run_migration 3 4 "${database}" || return 1
        version=4
    fi
    if [[ "$version" == "4" ]]; then
        # This migration script upgrades the gravity and list views
        # implementing necessary changes for per-client blocking
        run_migration 4 5 "${database}" || return 1
        version=5
    fi
    if [[ "$version" == "5" ]]; then
        # This migration script upgrades the adlist view
        # to return an ID used in gravity.sh
        run_migration 5 6 "${database}" || return 1
        version=6
    fi
    if [[ "$version" == "6" ]]; then
        # This migration script adds a special group with ID 0
        # which is automatically associated to all clients not
        # having their own group assignments
        run_migration 6 7 "${database}" || return 1
        version=7
    fi
    if [[ "$version" == "7" ]]; then
        # This migration script recreated the group table
        # to ensure uniqueness on the group name
        # We also add date_added and date_modified columns
        run_migration 7 8 "${database}" || return 1
        version=8
    fi
    if [[ "$version" == "8" ]]; then
        # This migration fixes some issues that were introduced
        # in the previous migration script.
        run_migration 8 9 "${database}" || return 1
        version=9
    fi
    if [[ "$version" == "9" ]]; then
        # This migration drops unused tables and creates triggers to remove
        # obsolete groups assignments when the linked items are deleted
        run_migration 9 10 "${database}" || return 1
        version=10
    fi
    if [[ "$version" == "10" ]]; then
        # This adds timestamp and an optional comment field to the client table
        # These fields are only temporary and will be replaces by the columns
        # defined in gravity.db.sql during gravity swapping. We add them here
        # to keep the copying process generic (needs the same columns in both the
        # source and the destination databases).
        run_migration 10 11 "${database}" || return 1
        version=11
    fi
    if [[ "$version" == "11" ]]; then
        # Rename group 0 from "Unassociated" to "Default"
        run_migration 11 12 "${database}" || return 1
        version=12
    fi
    if [[ "$version" == "12" ]]; then
        # Add column date_updated to adlist table
        run_migration 12 13 "${database}" || return 1
        version=13
    fi
    if [[ "$version" == "13" ]]; then
        # Add columns number and status to adlist table
        run_migration 13 14 "${database}" || return 1
        version=14
    fi
    if [[ "$version" == "14" ]]; then
        # Changes the vw_adlist created in 5_to_6
        run_migration 14 15 "${database}" || return 1
        version=15
    fi
    if [[ "$version" == "15" ]]; then
        # Add column abp_entries to adlist table
        run_migration 15 16 "${database}" || return 1
        version=16
    fi
    if [[ "$version" == "16" ]]; then
        # Add antigravity table
        # Add column type to adlist table (to support adlist types)
        run_migration 16 17 "${database}" || return 1
        version=17
    fi
    if [[ "$version" == "17" ]]; then
        # Add adlist.id to vw_gravity and vw_antigravity
        run_migration 17 18 "${database}" || return 1
        version=18
    fi
    if [[ "$version" == "18" ]]; then
        # Modify DELETE triggers to delete BEFORE instead of AFTER to prevent
        # foreign key constraint violations
        run_migration 18 19 "${database}" || return 1
        version=19
    fi
    if [[ "$version" == "19" ]]; then
        # Update views to use new allowlist/denylist names
        run_migration 19 20 "${database}" || return 1
        version=20
    fi
}
