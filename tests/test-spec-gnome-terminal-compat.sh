#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
spec="$repo_root/stillTerminal.spec"

assert_contains() {
    local expected=$1
    if ! grep -Fq "$expected" "$spec"; then
        printf 'FAIL: spec is missing: %s\n' "$expected" >&2
        exit 1
    fi
}

assert_contains 'Recommends:     still-terminal-gnome-terminal%{?_isa} = %{version}-%{release}'
assert_contains '%package gnome-terminal'
assert_contains 'Requires:       still-terminal%{?_isa} = %{version}-%{release}'
assert_contains 'Conflicts:      gnome-terminal'
assert_contains '%description gnome-terminal'
assert_contains '%files gnome-terminal'
assert_contains '%{_bindir}/gnome-terminal'

printf 'RPM compatibility subpackage tests passed\n'
