#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
PLUG="$ROOT/plugins/ywli-dev"
HOOK="$PLUG/scripts/session-start.sh"
BLOCK="$PLUG/scripts/block.sh"

blk() { "$SSVA_BASH" "$BLOCK" "$@" 2>/dev/null; }
replace_in() { local t; t="$(mktemp "${TMPDIR:-/tmp}/ssh.XXXXXX")"; sed "s/$2/$3/g" "$1" > "$t" && mv "$t" "$1"; }
swap6() { replace_in "$1/composer.json" '"\^5"' '"^6"'; replace_in "$1/composer.lock" '"version": "5\.[0-9.]*"' '"version": "6.1.2"'; }
# run_hook <project-dir> -> sets OUT, ERR, RC; cwd is a neutral dir
run_hook() {
  local ef; ef="$(mktemp "${TMPDIR:-/tmp}/sshe.XXXXXX")"
  OUT="$(cd "${TMPDIR:-/tmp}" && CLAUDE_PROJECT_DIR="$1" "$SSVA_BASH" "$HOOK" 2>"$ef")"; RC=$?
  ERR="$(cat "$ef")"; rm -f "$ef"
}
check_quiet() { assert_eq "" "$ERR" "stderr empty: $1"; assert_eq 0 "$RC" "rc 0: $1"; }

[ -x "$HOOK" ] && assert_eq 1 1 "exec" || _fail "session-start.sh executable" "x" "missing/not executable"

# hooks.json
HJ="$PLUG/hooks/hooks.json"
assert_file_contains "$HJ" '"SessionStart"'
assert_file_contains "$HJ" '"matcher": "startup|resume|clear|compact"'
assert_file_contains "$HJ" 'bash \"${CLAUDE_PLUGIN_ROOT}/scripts/session-start.sh\"'
assert_file_contains "$HJ" '"timeout": 10'

# non-git temp dir
t="$(mktemp -d "${TMPDIR:-/tmp}/ssng.XXXXXX")"
run_hook "$t"; assert_eq "" "$OUT" "non-git silent"; check_quiet "non-git"

# notss
d="$(make_git_fixture notss)"
run_hook "$d"; assert_eq "" "$OUT" "notss silent"; check_quiet "notss"
assert_eq "" "$(cd "$d" && git status --porcelain --ignored)" "notss nothing created"

# ss5 without init
d="$(make_git_fixture ss5)"
run_hook "$d"; assert_eq "" "$OUT" "uninit silent"; check_quiet "uninit"
[ ! -e "$d/CLAUDE.md" ] && [ ! -e "$d/CLAUDE.local.md" ] && assert_eq 1 1 "no files" || _fail "uninit wrote" "none" "exists"

# init, no change -> silent
d="$(make_git_fixture ss5)"; blk init "$d" >/dev/null
cp "$d/CLAUDE.md" "$d/snap"
run_hook "$d"; assert_eq "" "$OUT" "no change silent"; check_quiet "no change"
cmp -s "$d/CLAUDE.md" "$d/snap"; assert_eq 0 "$?" "no change: file identical"

# major change 5 -> 6
d="$(make_git_fixture ss5)"; blk init "$d" >/dev/null
swap6 "$d"
run_hook "$d"
EXPECT='{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"ss-version-aware: verzija promijenjena 5 → 6; blok osvježen."}}'
assert_eq "$EXPECT" "$OUT" "major json exact"; check_quiet "major"
assert_eq 1 "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "one line"
assert_file_contains "$d/CLAUDE.md" "⚠ Verzija promijenjena (5 → 6) — pokreni ss-version-aware."
# second run: no new change -> silent
run_hook "$d"; assert_eq "" "$OUT" "second run silent"; check_quiet "second run"

# fallback to PWD
d="$(make_git_fixture ss5)"; blk init "$d" >/dev/null; swap6 "$d"
ef="$(mktemp "${TMPDIR:-/tmp}/sshe.XXXXXX")"
OUT="$(cd "$d" && env -u CLAUDE_PROJECT_DIR "$SSVA_BASH" "$HOOK" 2>"$ef")"; RC=$?; ERR="$(cat "$ef")"; rm -f "$ef"
assert_eq "$EXPECT" "$OUT" "PWD fallback"; check_quiet "pwd fallback"

# mode change only
d="$(make_git_fixture ss5)"; blk init "$d" >/dev/null
cp "$FIXTURES_DIR/upgrade-5-6/composer.json" "$d/composer.json"
cp "$FIXTURES_DIR/upgrade-5-6/composer.lock" "$d/composer.lock"
run_hook "$d"
assert_eq '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"ss-version-aware: verzija promijenjena normal → upgrade; blok osvježen."}}' "$OUT" "mode json exact"
check_quiet "mode"

# block in CLAUDE.local.md, CLAUDE.md tracked
d="$(make_git_fixture ss5)"
printf 'team\n' > "$d/CLAUDE.md"; (cd "$d" && git add CLAUDE.md && git commit -q -m c --no-gpg-sign)
blk init "$d" >/dev/null; swap6 "$d"
cp "$d/CLAUDE.md" "$d/snap"
run_hook "$d"
assert_eq "$EXPECT" "$OUT" "local json"; check_quiet "local"
assert_file_contains "$d/CLAUDE.local.md" "⚠ Verzija promijenjena (5 → 6)"
cmp -s "$d/CLAUDE.md" "$d/snap"; assert_eq 0 "$?" "tracked CLAUDE.md byte-identical"
(cd "$d" && git diff --exit-code -- CLAUDE.md >/dev/null 2>&1); assert_eq 0 "$?" "no diff in tracked CLAUDE.md"

# missing dir: still silent, rc 0
run_hook "/nonexistent/dir/$$"; assert_eq "" "$OUT" "missing dir silent"; check_quiet "missing dir"

# silent rewrite (CHANGED=1 without major/mode change): lock hash differs only
d="$(make_git_fixture ss5)"; blk init "$d" >/dev/null
replace_in "$d/composer.lock" '"version": "5\.[0-9.]*"' '"version": "5.9.9"'
run_hook "$d"; assert_eq "" "$OUT" "silent rewrite"; check_quiet "silent rewrite"

finish
