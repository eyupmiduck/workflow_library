#!/bin/sh
# Shared helpers for the local-DB scripts, used by the projects that mount this
# repository at scripts/.
#
# Sourced, not executed: provides repo_root resolution, project-name detection
# and a per-checkout Compose project name so two checkouts (or two developers)
# do not operate on the same stack.

# Resolve the repository root from a script path, robust to PATH-based
# invocation (where $0 has no directory) and to symlinks where readlink -f is
# unavailable (macOS/BSD). Falls back to the script's directory.
resolve_repo_root() {
    script_path="$1"
    # A bare basename (found via PATH) has no directory separator; resolve it
    # with command -v first so dirname does not use the caller's directory.
    case "$script_path" in
        */*) ;;
        *) script_path="$(command -v "$script_path" 2>/dev/null || printf '%s' "$script_path")" ;;
    esac
    if command -v readlink >/dev/null 2>&1; then
        resolved="$(readlink -f "$script_path" 2>/dev/null || true)"
        [ -n "$resolved" ] && script_path="$resolved"
    fi
    (cd "$(dirname "$script_path")/.." && pwd)
}

# The project name: the repository-root directory basename (e.g. dml_utils),
# overridable with PROJECT (for example in CI). Nothing hardcodes dml/ddl.
project_name() {
    repo_root="$1"
    printf '%s' "${PROJECT:-$(basename "$repo_root")}"
}

# A stable, checkout-specific Compose project name: the Compose default
# (basename of the directory) would clash between clones named the same, and a
# constant would clash between checkouts. Hashing the checkout path keeps each
# checkout isolated, and prefixing the project name keeps two projects apart.
compose_project_name() {
    repo_root="$1"
    project="$(project_name "$repo_root")"
    if command -v sha256sum >/dev/null 2>&1; then
        digest="$(printf '%s' "$repo_root" | sha256sum | cut -c1-12)"
    elif command -v shasum >/dev/null 2>&1; then
        digest="$(printf '%s' "$repo_root" | shasum -a 256 | cut -c1-12)"
    else
        # Fallback: sanitize the path itself (collisions are unlikely enough).
        digest="$(printf '%s' "$repo_root" | tr -c 'a-z0-9' '-' | tail -c 40)"
    fi
    printf '%s_%s\n' "$project" "$digest"
}
