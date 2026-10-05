# workflow_library

Shared GitHub Actions and build/dev shims for the `dml_utils` and `ddl_utils`
projects.

## Reusable workflows

The `.github/workflows/` files are reusable workflows (`on: workflow_call`),
pinned by commit SHA from each consumer's own workflow file:

- `maven.yml` — builds the custom PostgreSQL image and runs the Maven build and
  tests against each PostgreSQL version in the matrix.
- `maven-release.yml` — tag-driven release: build, deploy to GitHub Packages,
  create the GitHub Release.
- `liquibase-changelog-linter.yml`, `codeql.yml`, `secret-scan.yml`,
  `dependabot-automerge.yml`, `ocr-review.yml`.

Both Maven workflows take a `project` input (the repository basename, e.g.
`dml_utils`) and build the image from the shared `postgres/` context.

## Build and dev shims

The repository root is the shared shim directory. Each project mounts this
repository as a git submodule at `scripts/`, so the files appear as
`scripts/<name>` in the consumer:

- `postgres/Dockerfile`, `postgres/roles.sql.tmpl` — the custom PostgreSQL image
  (roles, `plpgsql_check`, `pg_background`). The project name is rendered into
  `roles.sql` at build time from the `PROJECT` build arg.
- `build-postgres-image.sh` — builds `<project>-utils-postgres:<tag>` from the
  base image, deriving the tag and roles from the project name.
- `lib.sh` — `resolve_repo_root`, `project_name` and `compose_project_name`.
- `start-local-db.sh`, `stop-local-db.sh`, `refresh-local-db.sh` — the local
  Docker Compose stack.
- `sqlfluff-fix.sh` — SQLFluff auto-fix for the changelog module.
- `cut-release.sh` — tag the current `main` and push the release tag.

### Project name

Every script derives the project name from the repository-root directory
basename (for example `dml_utils`), overridable with the `PROJECT` environment
variable (used by CI). Nothing hardcodes `dml`/`ddl`.

### Consuming the shims

In a consumer repository:

```sh
git submodule add https://github.com/eyupmiduck/workflow_library.git scripts
git submodule update --init
```

and check out with `submodules: true` in CI. Keep the submodule commit and the
reusable-workflow `uses:` SHA in step.

## Documentation

- [`docs/adr/0001-shared-build-dev-shims.md`](docs/adr/0001-shared-build-dev-shims.md)
  — why the shims live here and how they are consumed.
