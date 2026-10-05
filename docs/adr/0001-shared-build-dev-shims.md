# ADR 0001: Share build and dev shims through workflow_library

- **Status:** Accepted
- **Date:** 2026-10-05
- **Bead:** dml-b2l.1 (epic dml-b2l, tracked in `dml_utils`)

## Context

`dml_utils` and `ddl_utils` carry the same development and build shims. Most are
identical or differ by a single project token:

| File | Difference between the repos |
|------|------------------------------|
| `scripts/start-local-db.sh`, `stop-local-db.sh`, `refresh-local-db.sh` | identical |
| `scripts/lib.sh` | `printf 'dml_utils_%s'` vs `printf 'ddl_utils_%s'` |
| `scripts/sqlfluff-fix.sh` | changelog module directory |
| `scripts/cut-release.sh` | one repository URL |
| `.sqlfluff` | `max_line_length` 120 vs 100 |
| `scripts/build-postgres-image.sh` | dml_utils derives a collision-safe tag; ddl_utils is simpler |
| `docker/postgres/Dockerfile` | dml_utils additionally builds `pg_background` |
| `docker/postgres/roles.sql` | project prefix; dml_utils additionally reconciles roles, owns the `liquibase` schema, and grants `pgbackground_role` |
| `compose.yaml` | prefix, database name, host port (dml_utils 5433, ddl_utils 5432) |
| `docker_java_config/pom.xml` | parent artifactId only |

GitHub Actions workflows are **already** shared through `workflow_library`
(reusable workflows pinned by commit SHA; the per-repo workflow files are thin
parameterized callers). The reusable `maven.yml` still delegates the custom
image build to a per-repo `scripts/build-postgres-image.sh` via the
`postgres-image-script` and `postgres-image-prefix` inputs.

`docker_java_config` exists to pin the docker-java Docker API version for
Testcontainers **<= 1.21.3**. Both consumers moved to Testcontainers 2.0.5 in
the dml-on2 epic, so the shim may now be obsolete.

## Decision

**Extend `workflow_library` into the shared build/dev library, consumed by each
project as a git submodule mounted at `scripts/`.**

1. **Home and layout.** The shared shims live at the `workflow_library`
   repository root: `lib.sh`, `start-local-db.sh`, `stop-local-db.sh`,
   `refresh-local-db.sh`, `build-postgres-image.sh`, `sqlfluff-fix.sh`,
   `cut-release.sh`, `compose.yaml`, `.sqlfluff`, and the image build context
   `postgres/Dockerfile` + `postgres/roles.sql`. Each consumer adds
   `workflow_library` as a submodule at `scripts/`, so the existing invocation
   paths (`scripts/start-local-db.sh`, `scripts/build-postgres-image.sh`,
   `scripts/postgres/...`) keep working. Because `scripts/` becomes a submodule,
   a repo-specific script must live outside it.

2. **Project identity is parameterized, not copied.** The shared scripts derive
   the project prefix from the repository-root directory basename, normalized
   (`dml_utils` -> `dml-utils-`), and the changelog module from the same
   basename (`dml_utils`). A root `.shimrc` (or the `PROJECT`/`PROJECT_PREFIX`
   environment) overrides both. CI passes the prefix explicitly. No script
   hardcodes `dml`/`ddl`.

3. **CI builds the image from the shared context.** The reusable
   `workflow_library` `maven.yml` checks out the caller with `submodules: true`
   and builds `scripts/postgres/Dockerfile` itself; the `postgres-image-script`
   and `postgres-image-prefix` inputs collapse to a single `project-prefix`
   input. The per-repo workflow callers pass one value.

4. **`compose.yaml` is shared and parameterized.** It uses the project/module,
   host port, database name and volume name from a per-repo `.env` (committed)
   or the `PROJECT` environment, and is invoked with an explicit
   `--project-directory` so its relative volume paths resolve against the repo
   root, not the submodule directory.

5. **`.sqlfluff` is shared.** The line-length divergence is resolved to one
   value (chosen in `dml-b2l.4`; 120 to avoid reformatting `dml_utils`) and the
   file is consumed through a repository-root symlink to `scripts/.sqlfluff` (or
   an explicit `--config`), so SQLFluff still discovers it by walking up.

6. **`docker_java_config`.** `dml-b2l.2` first establishes whether it is still
   required on Testcontainers 2.0.5. If not, it is removed from both repos. If
   it is still required, `docker-java.properties` is single-sourced from the
   submodule and each repo keeps only a thin packaging module that references
   it (no new published artifact), rather than two hand-maintained copies.

7. **Pins stay explicit.** The submodule is pinned to a `workflow_library`
   commit SHA, and the reusable workflow `uses:` lines are pinned to the same
   SHA. Bumping the shared library is one deliberate change in each consumer.

## Alternatives considered

- **Templates plus a sync script and a CI drift check.** Keeps the files
  vendored (no submodule, no onboarding step) and single-sources the content,
  but adds a generation tool and a fail-on-drift gate, and the generated files
  still look like copies. Rejected in favour of a real single source.
- **A dedicated `build_utils` repository.** Cleaner separation from CI
  workflows, but one more repository to create, pin and maintain, with the same
  submodule mechanics. `workflow_library` already exists and is already pinned
  by both repos; extending it avoids a second pin.
- **Keep the shims per-repo.** The status quo, and exactly the duplication this
  work removes. Rejected.
- **Publish the shims as a Maven artifact.** Works for `docker_java_config` but
  not for shell scripts and the Docker build context, which are not Maven
  artifacts. Rejected as the general mechanism.

## Consequences

Positive:

- One canonical source for every shim; a fix lands once.
- CI and devs run the same scripts at the same pinned revision.
- The reusable workflow owns the image build, so consumers no longer need a
  per-repo image script.

Negative / risks:

- Contributors must initialize the submodule (`git submodule update --init`);
  CI must check out with `submodules: true`.
- Two pins to keep aligned (submodule SHA and workflow `uses:` SHA).
- `scripts/` can no longer hold repo-specific scripts.
- Sharing `compose.yaml` and `.sqlfluff` requires path/parameterization care and
  a resolved line-length choice.

## Revisit triggers

- A third consumer appears with a materially different image or dev stack.
- The submodule workflow proves too heavy for contributors.
- `workflow_library` needs to stay strictly workflow-only.

## References

- Epic: bead `dml-b2l`; this decision: `dml-b2l.1`.
- Consumers of the shared shims: beads `dml-b2l.2`, `.3`, `.4`.
- Prior art: the reusable-workflow pattern in `workflow_library` (pinned by
  SHA), and ADR 0004 in `liquibase_validation` (single shared source).
