#!/bin/sh
# Start the local development database.
#
# Usage: scripts/start-local-db.sh
#
# This starts the PostgreSQL container and applies the changelog, waiting for
# the migration to finish successfully before returning.

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/lib.sh"

repo_root="$(resolve_repo_root "$0")"
compose_project="$(compose_project_name "$repo_root")"
PROJECT="$(project_name "$repo_root")"
export PROJECT
# The custom image tag for this project (hyphens, not underscores). Override
# POSTGRES_IMAGE to pin a version other than the default.
POSTGRES_IMAGE="${POSTGRES_IMAGE:-$(printf '%s' "$PROJECT" | tr '_' '-')-postgres:17-alpine}"
export POSTGRES_IMAGE

cd "$repo_root"

if ! command -v docker >/dev/null 2>&1; then
    echo "docker is required but was not found on PATH" >&2
    exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
    echo "docker compose (v2) is required but is not available" >&2
    exit 1
fi

# Pin the compose file, project directory and per-checkout project name so an
# inherited COMPOSE_FILE / project name cannot make this act on an unrelated
# stack, and two checkouts do not share one stack. --project-directory makes the
# compose file's relative paths and the project .env resolve against the repo
# root rather than the scripts/ submodule. Bring up PostgreSQL and wait for its
# healthcheck.
docker compose --project-name "$compose_project" --project-directory "$repo_root" \
    --file "$script_dir/compose.yaml" up -d --wait postgres

# The liquibase service is one-shot with no healthcheck, so `up --wait` cannot
# wait for the migration. Run it explicitly and propagate its exit status.
docker compose --project-name "$compose_project" --project-directory "$repo_root" \
    --file "$script_dir/compose.yaml" run --rm -T liquibase
