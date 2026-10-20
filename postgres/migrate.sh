#!/bin/sh
# Apply the local-development changelogs: ddl_utils first (when the checkout
# has the unpacked ddl_utils changelog), then the project's own changelog.
#
# Run inside the `liquibase` service by scripts/compose.yaml. PROJECT is supplied
# by the compose environment; the repository root is mounted at /repo.
set -eu

# Run from the mounted checkout so Liquibase's default search path (the current
# working directory) contains both changelog trees.
cd /repo

: "${PROJECT:?PROJECT must be set}"

# Downloads the PostgreSQL JDBC driver on each run; the local stack therefore
# needs network access to the package registry.
lpm add postgresql --global

update_changelog() {
    table="$1"
    lock_table="$2"
    changelog="$3"
    liquibase \
        --url="jdbc:postgresql://postgres:5432/${PROJECT}" \
        --username="${PROJECT}_owner" \
        --password="${PROJECT}_owner" \
        --changelog-file="$changelog" \
        --liquibase-schema-name=liquibase \
        --database-changelog-table-name="$table" \
        --database-changelog-lock-table-name="$lock_table" \
        update
}

# dml_utils assumes ddl_utils is installed in the same database. The versioned
# ddl_utils dependency is unpacked into the project's build output by
# scripts/start-local-db.sh and scripts/refresh-local-db.sh; the ddl_utils
# repository has no such path and skips this step.
ddl_utils_changelog="${PROJECT}/target/classes/db/changelog-install/ddl-utils/db/changelog/db.changelog-master.xml"
if [ -f "$ddl_utils_changelog" ]; then
    update_changelog \
        ddl_utils_databasechangelog \
        ddl_utils_databasechangeloglock \
        "$ddl_utils_changelog"
fi

update_changelog \
    "${PROJECT}_databasechangelog" \
    "${PROJECT}_databasechangeloglock" \
    "${PROJECT}/src/main/resources/db/changelog/db.changelog-master.xml"
