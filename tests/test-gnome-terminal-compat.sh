#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

valac --pkg posix \
    "$repo_root/compat/gnome-terminal.vala" \
    -o "$tmpdir/gnome-terminal"

cat >"$tmpdir/still-terminal" <<'EOF'
#!/usr/bin/env bash
: >"$STILL_TERMINAL_CAPTURE"
for arg in "$@"; do
    printf '%s\0' "$arg" >>"$STILL_TERMINAL_CAPTURE"
done
EOF
chmod +x "$tmpdir/still-terminal"

capture="$tmpdir/argv"
export STILL_TERMINAL_CAPTURE="$capture"
export PATH="$tmpdir:$PATH"

assert_argv() {
    local description=$1
    shift
    mapfile -d '' -t actual <"$capture"
    if [[ ${#actual[@]} -ne $# ]]; then
        printf 'FAIL: %s: expected %d arguments, got %d\n' \
            "$description" "$#" "${#actual[@]}" >&2
        printf 'actual: <%s>\n' "${actual[*]}" >&2
        exit 1
    fi

    local index=0
    local expected
    for expected in "$@"; do
        if [[ ${actual[$index]} != "$expected" ]]; then
            printf 'FAIL: %s: argument %d: expected <%s>, got <%s>\n' \
                "$description" "$index" "$expected" "${actual[$index]}" >&2
            exit 1
        fi
        ((index += 1))
    done
}

"$tmpdir/gnome-terminal"
assert_argv "no options"

"$tmpdir/gnome-terminal" --working-directory "/tmp/a directory" -- \
    sh -c 'printf "%s\n" "$HOME"'
assert_argv "working directory and modern command" \
    --working-directory "/tmp/a directory" -- \
    sh -c 'printf "%s\n" "$HOME"'

"$tmpdir/gnome-terminal" --working-directory=/srv/project --title "Build log" \
    --zoom=1.25 --full-screen --window -q -e 'python3 -q'
assert_argv "terminal presentation and legacy command" \
    --working-directory /srv/project --title "Build log" \
    --zoom 1.25 --fullscreen --command 'python3 -q'

"$tmpdir/gnome-terminal" -w /var/tmp -t Status -x env 'A=a b' printf '%s\n' ok
assert_argv "legacy execute preserves argument boundaries" \
    --working-directory /var/tmp --title Status -- \
    env 'A=a b' printf '%s\n' ok

if "$tmpdir/gnome-terminal" --wait >"$tmpdir/stdout" 2>"$tmpdir/stderr"; then
    printf 'FAIL: unsupported --wait unexpectedly succeeded\n' >&2
    exit 1
fi
if ! grep -Fq 'option is not supported: --wait' "$tmpdir/stderr"; then
    printf 'FAIL: unsupported --wait did not explain the incompatibility\n' >&2
    exit 1
fi

printf 'gnome-terminal compatibility translation tests passed\n'
