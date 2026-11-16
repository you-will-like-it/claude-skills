#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

assert_eq a a "assert_eq passes on equal"

d="$(cd /tmp && make_git_fixture ss5)"
assert_file_contains "$d/composer.lock" '"silverstripe/framework"'
assert_eq "" "$(cd "$d" && git status --porcelain)" "fixture git tree clean"
assert_contains "$(cd "$d" && git log --oneline)" "fixture" "fixture has a commit"
rm -rf "$d"

assert_file_contains "$ROOT/.claude-plugin/marketplace.json" '"name": "ywli-dev"'
assert_file_contains "$ROOT/plugins/ywli-dev/.claude-plugin/plugin.json" '"name": "ywli-dev"'

assert_not_contains "abc" "z" "assert_not_contains"
assert_exit 0 true
assert_exit 3 "$SSVA_BASH" -c 'exit 3'

# SSVA_BASH routing: the test file, "$SSVA_BASH" and a bare `bash` (used inside the plugin scripts) are one interpreter
assert_eq "$BASH_VERSION" "$("$SSVA_BASH" -c 'echo "$BASH_VERSION"')" "SSVA_BASH runs this test file"
assert_eq "$BASH_VERSION" "$(bash -c 'echo "$BASH_VERSION"')" "bare bash resolves to SSVA_BASH"
# private TMPDIR, removed on exit
case "$TMPDIR" in */ssva-test.*) assert_eq 1 1 "private TMPDIR" ;; *) _fail "private TMPDIR" "*/ssva-test.*" "$TMPDIR" ;; esac
left="$("$SSVA_BASH" -c '. "$1/lib.sh"; echo "$TMPDIR"' x "$HERE")"
[ -n "$left" ] && [ ! -e "$left" ] && assert_eq 1 1 "lib.sh removes its TMPDIR on exit" || _fail "lib.sh TMPDIR cleanup" "removed" "$left"

# CRLF fixture keeps CRLF after git copy
d="$(make_git_fixture crlf-ss5)"
assert_contains "$(od -c "$d/composer.lock" | head -50)" '\r' "crlf preserved"
rm -rf "$d"

# stale vendor committed
d="$(make_git_fixture vendor-stale)"
assert_eq "" "$(cd "$d" && git status --porcelain)" "vendor-stale clean"
[ -f "$d/vendor/composer/installed.json" ] || _fail "vendor/composer/installed.json missing in git fixture" "present" "absent"
rm -rf "$d"

finish
