#!/bin/sh
# Bump the root POM's <revision> to the next patch snapshot after a released
# version. Used by the reusable maven-release.yml once the GitHub Release is
# created, to open a follow-up "next development version" PR.
#
# Usage: bump-snapshot.sh [--print] <released-version> [pom-file]
#   e.g. bump-snapshot.sh 1.0.0              # -> 1.0.1-SNAPSHOT in ./pom.xml
#        bump-snapshot.sh v1.2.3 pom.xml
#        bump-snapshot.sh --print 1.0.0      # print 1.0.1-SNAPSHOT, change nothing
#
# The tag is the single source of truth for the release, so the new version is
# derived from the argument (the tag), not from the POM's current value, which
# may be stale. Prints the new revision on stdout.

set -eu

usage() {
    echo "usage: bump-snapshot.sh [--print] <released-version> [pom-file]" >&2
}

print_only=
version=
pom=
for arg in "$@"; do
    case "$arg" in
        -p | --print)
            print_only=1
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            echo "unknown option: $arg" >&2
            usage
            exit 2
            ;;
        *)
            if [ -z "$version" ]; then
                version="$arg"
            elif [ -z "$pom" ]; then
                pom="$arg"
            else
                echo "unexpected extra argument: $arg" >&2
                usage
                exit 2
            fi
            ;;
    esac
done

if [ -z "$version" ]; then
    usage
    exit 2
fi
pom="${pom:-pom.xml}"

# Keep only the release core: strip build metadata, then any prerelease, and
# bump the patch. A release outranks its own prereleases, so the next
# development line is always the next patch.
core="${version#v}"
core="${core%%+*}"
core="${core%%-*}"
if ! printf '%s' "$core" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "invalid version '$version': expected <major>.<minor>.<patch>" >&2
    exit 1
fi
# Compute in awk so numeric fields are decimal (a leading zero is not read as
# octal the way POSIX shell arithmetic would).
next="$(printf '%s\n' "$core" | awk -F. '{ printf "%d.%d.%d-SNAPSHOT\n", $1, $2, $3 + 1 }')"

if [ -n "$print_only" ]; then
    printf '%s\n' "$next"
    exit 0
fi

if [ ! -f "$pom" ]; then
    echo "POM not found: $pom" >&2
    exit 1
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/bump-snapshot.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
# Replace only the first <revision> element and stop, so a comment that
# mentions ${revision} or another element cannot be rewritten. Fail loudly if
# there is no <revision> to bump, rather than silently changing nothing.
if ! awk -v new="$next" '
    !done && /<revision>[^<]*<\/revision>/ {
        sub(/<revision>[^<]*<\/revision>/, "<revision>" new "</revision>")
        done = 1
    }
    { print }
    END { exit done ? 0 : 1 }
' "$pom" > "$tmp"; then
    echo "no <revision> element found in $pom" >&2
    exit 1
fi
mv "$tmp" "$pom"
trap - EXIT

printf '%s\n' "$next"
