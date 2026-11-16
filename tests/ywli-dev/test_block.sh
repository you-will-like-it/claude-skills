#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
BLOCK="$ROOT/plugins/ywli-dev/scripts/block.sh"
START='<!-- ss-version-aware:start -->'
END='<!-- ss-version-aware:end -->'

blk() { "$SSVA_BASH" "$BLOCK" "$@" 2>/dev/null; }
count_start() { grep -c -F -- "$START" "$1" | tr -d ' '; }
block_lines() { # file -> number of lines strictly between markers
  tr -d '\r' < "$1" | awk -v s="$START" -v e="$END" '$0==s{i=1;next} $0==e{i=0} i{n++} END{print n+0}'
}
exclude_file() { (cd "$1" && p="$(git rev-parse --git-path info/exclude)"; case "$p" in /*) echo "$p" ;; *) echo "$1/$p" ;; esac); }
replace_in() { # file from to (via temp, no sed -i)
  local t; t="$(mktemp "${TMPDIR:-/tmp}/ssr.XXXXXX")"
  sed "s/$2/$3/g" "$1" > "$t" && mv "$t" "$1"
}

# --- executable bit, usage ---
[ -x "$BLOCK" ] && assert_eq 1 1 "exec" || _fail "block.sh executable" "x" "not executable"
assert_exit 64 "$SSVA_BASH" "$BLOCK" bogus
assert_exit 64 "$SSVA_BASH" "$BLOCK"

# --- init: no CLAUDE.md ---
d="$(make_git_fixture ss5)"
out="$(blk init "$d")"; rc=$?
assert_eq 0 "$rc" "init rc"
assert_contains "$out" "TARGET=CLAUDE.md" "init target"
assert_not_contains "$out" "NOTE=" "no note in git"
assert_file_contains "$d/CLAUDE.md" "$START"
assert_file_contains "$d/CLAUDE.md" "$END"
assert_file_contains "$d/CLAUDE.md" "SilverStripe 5."
assert_file_contains "$d/CLAUDE.md" "(major 5) — režim: normal"
assert_file_contains "$d/CLAUDE.md" "Build: webpack"
assert_file_contains "$d/CLAUDE.md" "PHP 8.2 (DDEV)"
assert_file_contains "$d/CLAUDE.md" "Prije upotrebe bilo kojeg SilverStripe API-ja koristi skill ss-version-aware (referenca za ovu verziju); ako stavka nije u referenci, provjeri u vendor/."
assert_file_contains "$(exclude_file "$d")" "/CLAUDE.md"
assert_eq "" "$(cd "$d" && git status --porcelain)" "status clean after init"
# last line before end marker is lock:
assert_eq "lock: $("$SSVA_BASH" "$ROOT/plugins/ywli-dev/scripts/detect.sh" "$d" | sed -n 's/^LOCK_HASH=//p')" \
  "$(grep -B1 -F -- "$END" "$d/CLAUDE.md" | head -n 1)" "lock is last line"
# init twice: one block, one exclude line
blk init "$d" >/dev/null
assert_eq 1 "$(count_start "$d/CLAUDE.md")" "one start marker after 2 inits"
assert_eq 1 "$(grep -cxF '/CLAUDE.md' "$(exclude_file "$d")")" "one exclude entry"

# --- init: tracked CLAUDE.md -> CLAUDE.local.md ---
d="$(make_git_fixture ss5)"
printf '# Team rules\nkeep me\n' > "$d/CLAUDE.md"
(cd "$d" && git add CLAUDE.md && git commit -q -m c --no-gpg-sign)
out="$(blk init "$d")"
assert_contains "$out" "TARGET=CLAUDE.local.md" "tracked -> local"
(cd "$d" && git diff --exit-code >/dev/null 2>&1); assert_eq 0 "$?" "tracked CLAUDE.md untouched"
assert_eq "" "$(cd "$d" && git status --porcelain)" "status clean (tracked case)"
assert_file_contains "$(exclude_file "$d")" "/CLAUDE.local.md"
assert_file_contains "$d/CLAUDE.local.md" "$START"

# --- marker inside tracked CLAUDE.md is ignored ---
d="$(make_git_fixture ss5)"
printf 'x\n%s\nold\n%s\n' "$START" "$END" > "$d/CLAUDE.md"
(cd "$d" && git add CLAUDE.md && git commit -q -m c --no-gpg-sign)
before="$(cat "$d/CLAUDE.md")"
assert_eq "" "$(blk refresh "$d")" "refresh ignores tracked marker"
out="$(blk init "$d")"
assert_contains "$out" "TARGET=CLAUDE.local.md" "init avoids tracked marker file"
assert_eq "$before" "$(cat "$d/CLAUDE.md")" "tracked file byte-identical"
(cd "$d" && git diff --exit-code >/dev/null 2>&1); assert_eq 0 "$?" "no diff in tracked"

# --- existing untracked CLAUDE.md with text above and below ---
d="$(make_git_fixture ss5)"
printf 'ABOVE line\n\nsecond above\n' > "$d/CLAUDE.md"
blk init "$d" >/dev/null
printf '\nBELOW line\nlast below\n' >> "$d/CLAUDE.md"
cp "$d/CLAUDE.md" "$d/snap"
blk init "$d" >/dev/null
assert_eq 1 "$(count_start "$d/CLAUDE.md")" "exactly one start marker"
assert_file_contains "$d/CLAUDE.md" "ABOVE line"
assert_file_contains "$d/CLAUDE.md" "second above"
assert_file_contains "$d/CLAUDE.md" "BELOW line"
assert_file_contains "$d/CLAUDE.md" "last below"
cmp -s "$d/CLAUDE.md" "$d/snap"; assert_eq 0 "$?" "re-init idempotent byte-for-byte"
# existing file without trailing newline, then init: user text preserved, blank line separator
d="$(make_git_fixture ss5)"
printf 'no newline at end' > "$d/CLAUDE.md"
blk init "$d" >/dev/null
assert_eq "no newline at end" "$(head -n 1 "$d/CLAUDE.md")" "first line preserved"
assert_eq "" "$(sed -n 2p "$d/CLAUDE.md")" "blank separator line"
assert_eq "$START" "$(sed -n 3p "$d/CLAUDE.md")" "block starts line 3"

# --- CRLF CLAUDE.md ---
d="$(make_git_fixture crlf-ss5)"
printf 'Above crlf\r\nSecond\r\n' > "$d/CLAUDE.md"
blk init "$d" >/dev/null
assert_eq "$(printf 'Above crlf\r\nSecond\r\n' | od -c)" "$(head -n 2 "$d/CLAUDE.md" | od -c)" "crlf text above byte-identical"
# block lines use CRLF
assert_eq 0 "$(tr -d '\r' < "$d/CLAUDE.md" | grep -c . >/dev/null; grep -c -v "$(printf '\r')\$" "$d/CLAUDE.md" | tr -d ' ')" "all lines CRLF"
# text below a block survives replacement
printf 'Tail crlf\r\n' >> "$d/CLAUDE.md"
blk init "$d" >/dev/null
assert_eq 1 "$(count_start "$d/CLAUDE.md")" "crlf one block"
assert_eq "Tail crlf$(printf '\r')" "$(tail -n 1 "$d/CLAUDE.md")" "crlf tail preserved"
assert_eq "$(printf 'Above crlf\r\nSecond\r\n' | od -c)" "$(head -n 2 "$d/CLAUDE.md" | od -c)" "crlf head still identical"

# --- line count <= 15 ---
d="$(make_git_fixture upgrade-5-6)"; blk init "$d" >/dev/null
n="$(block_lines "$d/CLAUDE.md")"
[ "$n" -le 15 ] && assert_eq 1 1 "lines" || _fail "upgrade block <=15" "<=15" "$n"
assert_file_contains "$d/CLAUDE.md" "režim: upgrade → 6"
assert_file_contains "$d/CLAUDE.md" "Novi kod piši isključivo za SS6; postojeći mijenjaj prema mapi migracije i .claude/ss-upgrade-checklist.md."
d="$(make_git_fixture module-compat)"; blk init "$d" >/dev/null
n="$(block_lines "$d/CLAUDE.md")"
[ "$n" -le 15 ] && assert_eq 1 1 "lines" || _fail "compat block <=15" "<=15" "$n"
assert_file_contains "$d/CLAUDE.md" "režim: compat, kompatibilno: 5 6"
assert_file_contains "$d/CLAUDE.md" "Koristi samo API koji postoji u SS5 i SS6, ili verzijski uslovljen kod."
# modules line + separators
d="$(make_git_fixture ss6)"; blk init "$d" >/dev/null
assert_file_contains "$d/CLAUDE.md" "Moduli: silverstripe/cms="
assert_file_contains "$d/CLAUDE.md" ", dnadesign/silverstripe-elemental=6.0.1"
assert_file_contains "$d/CLAUDE.md" "PHP 8.3 (DDEV)"
assert_file_contains "$d/CLAUDE.md" "Build: vite"
# package.json only -> "Build: npm"
d="$(make_git_fixture upgrade-5-6)"; printf '{}\n' > "$d/package.json"
assert_contains "$(blk show "$d")" "Build: npm" "block shows Build: npm"
# no modules / no php -> lines omitted
d="$(make_git_fixture upgrade-5-6)"; blk init "$d" >/dev/null
assert_not_contains "$(cat "$d/CLAUDE.md")" "Moduli:" "no modules line"
assert_not_contains "$(cat "$d/CLAUDE.md")" "PHP " "no php line"

# --- show: no writes ---
d="$(make_git_fixture ss5)"
out="$(blk show "$d")"
assert_contains "$out" "$START" "show prints block"
[ ! -e "$d/CLAUDE.md" ] && assert_eq 1 1 "show wrote nothing" || _fail "show wrote file" "none" "CLAUDE.md"

# --- refresh: no block -> silent no-op ---
d="$(make_git_fixture ss5)"
out="$("$SSVA_BASH" "$BLOCK" refresh "$d" 2>&1)"; rc=$?
assert_eq 0 "$rc" "refresh noop rc"; assert_eq "" "$out" "refresh noop output"
[ ! -e "$d/CLAUDE.md" ] && [ ! -e "$d/CLAUDE.local.md" ] && assert_eq 1 1 "no files" || _fail "refresh created file" "none" "exists"
printf 'just notes\n' > "$d/CLAUDE.md"
assert_eq "" "$(blk refresh "$d")" "refresh with file but no block silent"
assert_eq "just notes" "$(cat "$d/CLAUDE.md")" "file untouched"

# --- refresh: no change ---
d="$(make_git_fixture ss5)"; blk init "$d" >/dev/null
cp "$d/CLAUDE.md" "$d/snap"
out="$(blk refresh "$d")"
assert_eq "CHANGED=0" "$out" "refresh no change"
cmp -s "$d/CLAUDE.md" "$d/snap"; assert_eq 0 "$?" "file unchanged"

# --- refresh: major change 5 -> 6 (constraint + lock) ---
d="$(make_git_fixture ss5)"; blk init "$d" >/dev/null
oldlock="$(grep '^lock: ' "$d/CLAUDE.md")"
printf 'keep after\n' >> "$d/CLAUDE.md"
replace_in "$d/composer.json" '"\^5"' '"^6"'
replace_in "$d/composer.lock" '"version": "5\.[0-9.]*"' '"version": "6.1.2"'
out="$(blk refresh "$d")"
assert_contains "$out" "CHANGED=1" "major refresh changed"
assert_contains "$out" "MAJOR_CHANGED=5->6" "major changed"
assert_file_contains "$d/CLAUDE.md" "⚠ Verzija promijenjena (5 → 6) — pokreni ss-version-aware."
assert_file_contains "$d/CLAUDE.md" "(major 6)"
assert_file_contains "$d/CLAUDE.md" "keep after"
assert_not_contains "$(grep '^lock: ' "$d/CLAUDE.md")" "$oldlock" "lock hash replaced"
assert_eq 1 "$(count_start "$d/CLAUDE.md")" "one block after refresh"
assert_eq "lock: " "$(grep -B1 -F -- "$END" "$d/CLAUDE.md" | head -n 1 | cut -c1-6)" "lock still last"
# warning persists across no-change refresh
out="$(blk refresh "$d")"
assert_eq "CHANGED=0" "$out" "second refresh no change"
assert_file_contains "$d/CLAUDE.md" "⚠ Verzija promijenjena (5 → 6)"
# ack removes it
assert_eq "" "$(blk ack "$d")" "ack silent"
assert_not_contains "$(cat "$d/CLAUDE.md")" "⚠" "ack removed warning"
assert_file_contains "$d/CLAUDE.md" "keep after"
# init also clears it
d2="$(make_git_fixture ss5)"; blk init "$d2" >/dev/null
replace_in "$d2/composer.json" '"\^5"' '"^6"'; replace_in "$d2/composer.lock" '"version": "5\.[0-9.]*"' '"version": "6.1.2"'
blk refresh "$d2" >/dev/null
blk init "$d2" >/dev/null
assert_not_contains "$(cat "$d2/CLAUDE.md")" "⚠" "init cleared warning"
# ack without block: no-op
d3="$(make_git_fixture ss5)"
assert_eq "" "$("$SSVA_BASH" "$BLOCK" ack "$d3" 2>&1)" "ack noop"
[ ! -e "$d3/CLAUDE.md" ] && assert_eq 1 1 "ack no file" || _fail "ack created" "none" "exists"

# --- refresh: mode change reported ---
d="$(make_git_fixture ss5)"; blk init "$d" >/dev/null
cp "$FIXTURES_DIR/upgrade-5-6/composer.json" "$d/composer.json"
cp "$FIXTURES_DIR/upgrade-5-6/composer.lock" "$d/composer.lock"
out="$(blk refresh "$d")"
assert_contains "$out" "MODE_CHANGED=normal->upgrade" "mode changed"
assert_not_contains "$out" "MAJOR_CHANGED" "major same"
assert_file_contains "$d/CLAUDE.md" "⚠ Verzija promijenjena (normal → upgrade)"

# --- refresh writes into CLAUDE.local.md when that holds the block ---
d="$(make_git_fixture ss5)"
printf 'team\n' > "$d/CLAUDE.md"; (cd "$d" && git add CLAUDE.md && git commit -q -m c --no-gpg-sign)
blk init "$d" >/dev/null
replace_in "$d/composer.json" '"\^5"' '"^6"'; replace_in "$d/composer.lock" '"version": "5\.[0-9.]*"' '"version": "6.1.2"'
out="$(blk refresh "$d")"
assert_contains "$out" "MAJOR_CHANGED=5->6" "local refresh"
assert_file_contains "$d/CLAUDE.local.md" "⚠ Verzija promijenjena (5 → 6)"
assert_eq "team" "$(cat "$d/CLAUDE.md")" "tracked untouched on refresh"

# --- notss ---
d="$(make_git_fixture notss)"
assert_exit 2 "$SSVA_BASH" "$BLOCK" init "$d"
out="$("$SSVA_BASH" "$BLOCK" init "$d" 2>&1 >/dev/null)"
assert_contains "$out" "not a SilverStripe" "stderr message"
[ ! -e "$d/CLAUDE.md" ] && assert_eq 1 1 "no file" || _fail "notss wrote" "none" "exists"

# --- worktree: exclude from git rev-parse --git-path ---
d="$(make_git_fixture ss5)"
wt="$(mktemp -d "${TMPDIR:-/tmp}/sswt.XXXXXX")/wt"
(cd "$d" && git worktree add -q "$wt" -b wtbranch >/dev/null 2>&1)
out="$(blk init "$wt")"
assert_contains "$out" "TARGET=CLAUDE.md" "worktree init"
ex="$(exclude_file "$wt")"
assert_file_contains "$ex" "/CLAUDE.md"
assert_eq "" "$(cd "$wt" && git status --porcelain)" "worktree status clean"

# --- subdirectory of a repo: root-anchored entry includes prefix ---
d="$(make_git_fixture ss5)"
mkdir -p "$d/sub"; cp "$FIXTURES_DIR/ss5/composer.json" "$FIXTURES_DIR/ss5/composer.lock" "$d/sub/"
(cd "$d" && git add -A && git commit -q -m s --no-gpg-sign)
out="$(blk init "$d/sub")"
assert_contains "$out" "TARGET=CLAUDE.md" "subdir init"
assert_file_contains "$(exclude_file "$d")" "/sub/CLAUDE.md"
assert_eq "" "$(cd "$d" && git status --porcelain)" "subdir status clean"

# --- outside git ---
t="$(mktemp -d "${TMPDIR:-/tmp}/ssng.XXXXXX")"
cp -R "$FIXTURES_DIR/ss5/." "$t/"
out="$(blk init "$t")"
assert_contains "$out" "TARGET=CLAUDE.md" "no-git target"
assert_contains "$out" "NOTE=no-git" "no-git note"
assert_file_contains "$t/CLAUDE.md" "$START"
assert_eq "CHANGED=0" "$(blk refresh "$t")" "no-git refresh"

# --- F1: both CLAUDE.md and CLAUDE.local.md tracked -> refuse ---
d="$(make_git_fixture ss5)"
printf 'a\n' > "$d/CLAUDE.md"; printf 'b\n' > "$d/CLAUDE.local.md"
(cd "$d" && git add -f CLAUDE.md CLAUDE.local.md && git commit -q -m c --no-gpg-sign)
exb="$(cat "$(exclude_file "$d")")"
out="$("$SSVA_BASH" "$BLOCK" init "$d" 2>&1)"; rc=$?
assert_eq 3 "$rc" "both tracked: exit 3"
assert_contains "$out" "block.sh: CLAUDE.local.md is tracked; refusing to write" "both tracked: message"
assert_eq "" "$(cd "$d" && git status --porcelain)" "both tracked: nothing modified"
assert_eq "$exb" "$(cat "$(exclude_file "$d")")" "both tracked: no exclude line"
assert_eq "" "$(blk refresh "$d")" "both tracked: refresh no-op"
assert_eq "" "$("$SSVA_BASH" "$BLOCK" ack "$d" 2>&1)" "both tracked: ack no-op"
assert_eq "b" "$(cat "$d/CLAUDE.local.md")" "both tracked: local untouched"

# --- F2: stray/quoted start marker before the real block ---
d="$(make_git_fixture ss5)"
printf 'Quoted marker: see below\n%s\nuser text between\n' "$START" > "$d/CLAUDE.md"
blk init "$d" >/dev/null
printf 'after text\n' >> "$d/CLAUDE.md"
cp "$d/CLAUDE.md" "$d/snap"
out1="$(blk refresh "$d")"; out2="$(blk refresh "$d")"
assert_eq "CHANGED=0" "$out1" "stray marker: first refresh"
assert_eq "CHANGED=0" "$out2" "stray marker: second refresh"
cmp -s "$d/CLAUDE.md" "$d/snap"; assert_eq 0 "$?" "stray marker: file byte-identical"
assert_file_contains "$d/CLAUDE.md" "user text between"
assert_file_contains "$d/CLAUDE.md" "Quoted marker: see below"

# --- F3: no trailing newline after the block ---
d="$(make_git_fixture ss5)"
blk init "$d" >/dev/null
printf 'tail no newline' >> "$d/CLAUDE.md"
blk init "$d" >/dev/null
assert_eq "" "$(tail -c 1 "$d/CLAUDE.md" | tr -d 'e')" "init: last byte is 'e'"
assert_eq 1 "$(count_start "$d/CLAUDE.md")" "init: single block"
replace_in "$d/composer.json" '"\^5"' '"^6"'; replace_in "$d/composer.lock" '"version": "5\.[0-9.]*"' '"version": "6.1.2"'
blk refresh "$d" >/dev/null
assert_eq "tail no newline" "$(tail -n 1 "$d/CLAUDE.md")" "refresh: tail text"
assert_eq "e" "$(tail -c 1 "$d/CLAUDE.md")" "refresh: still no EOL"
blk ack "$d" >/dev/null
assert_eq "tail no newline" "$(tail -n 1 "$d/CLAUDE.md")" "ack: tail text"
assert_eq "e" "$(tail -c 1 "$d/CLAUDE.md")" "ack: still no EOL"
# block is the last thing, no EOL after end marker
d="$(make_git_fixture ss5)"
blk init "$d" >/dev/null
printf '%s' "$(cat "$d/CLAUDE.md")" > "$d/c2"; mv "$d/c2" "$d/CLAUDE.md"
assert_eq ">" "$(tail -c 1 "$d/CLAUDE.md")" "setup: ends with marker, no EOL"
replace_in "$d/composer.json" '"\^5"' '"^6"'; replace_in "$d/composer.lock" '"version": "5\.[0-9.]*"' '"version": "6.1.2"'
blk refresh "$d" >/dev/null
assert_eq ">" "$(tail -c 1 "$d/CLAUDE.md")" "block-last: no EOL kept"
assert_eq "$END" "$(tail -n 1 "$d/CLAUDE.md")" "block-last: end marker last"
# CRLF, last line unterminated
d="$(make_git_fixture crlf-ss5)"
printf 'Head\r\n' > "$d/CLAUDE.md"
blk init "$d" >/dev/null
printf 'last crlf line' >> "$d/CLAUDE.md"
cp "$d/CLAUDE.md" "$d/snap"
blk init "$d" >/dev/null
cmp -s "$d/CLAUDE.md" "$d/snap"; assert_eq 0 "$?" "crlf no-EOL: init byte-identical"
replace_in "$d/composer.json" '"\^5"' '"^6"'
blk refresh "$d" >/dev/null
assert_eq "last crlf line" "$(tail -n 1 "$d/CLAUDE.md")" "crlf no-EOL: refresh tail"
assert_eq "e" "$(tail -c 1 "$d/CLAUDE.md")" "crlf no-EOL: no EOL after refresh"
assert_eq "$(printf 'Head\r\n' | od -c)" "$(head -n 1 "$d/CLAUDE.md" | od -c)" "crlf no-EOL: head identical"
# CRLF with end marker as unterminated last line
d="$(make_git_fixture crlf-ss5)"
blk init "$d" >/dev/null
tr -d '\r' < "$d/CLAUDE.md" | sed 's/$/\r/' > "$d/c2"
printf '%s' "$(cat "$d/c2")" > "$d/CLAUDE.md"; rm "$d/c2"
replace_in "$d/composer.json" '"\^5"' '"^6"'
blk refresh "$d" >/dev/null
assert_eq ">" "$(tail -c 1 "$d/CLAUDE.md")" "crlf block-last: no EOL"
assert_eq 1 "$(count_start "$d/CLAUDE.md")" "crlf block-last: one block"

# --- #2: no temp files left behind (init, refresh with a change, ack) ---
d="$(make_git_fixture ss5)"
pt="$TMPDIR/private-tmp"; mkdir -p "$pt"
before="$(ls -A "$pt" | grep -c '^ssva-' | tr -d ' ')"
TMPDIR="$pt" "$SSVA_BASH" "$BLOCK" init "$d" >/dev/null 2>&1
replace_in "$d/composer.json" '"\^5"' '"^6"'; replace_in "$d/composer.lock" '"version": "5\.[0-9.]*"' '"version": "6.1.2"'
out="$(TMPDIR="$pt" "$SSVA_BASH" "$BLOCK" refresh "$d" 2>/dev/null)"
assert_contains "$out" "CHANGED=1" "leak test: refresh rewrote the block"
TMPDIR="$pt" "$SSVA_BASH" "$BLOCK" ack "$d" >/dev/null 2>&1
TMPDIR="$pt" "$SSVA_BASH" "$BLOCK" show "$d" >/dev/null 2>&1
assert_eq "$before" "$(ls -A "$pt" | grep -c '^ssva-' | tr -d ' ')" "no ssva-* temp files left in TMPDIR"

# --- #3: new CLAUDE.md in a repo with AGENTS.md imports it (else Claude Code stops reading AGENTS.md) ---
d="$(make_git_fixture ss5)"
printf '# Agents\n' > "$d/AGENTS.md"; (cd "$d" && git add AGENTS.md && git commit -q -m a --no-gpg-sign)
out="$(blk init "$d")"
assert_contains "$out" "TARGET=CLAUDE.md" "agents: target"
assert_contains "$out" "NOTE=agents-md-imported" "agents: note"
assert_eq "@AGENTS.md" "$(sed -n 1p "$d/CLAUDE.md")" "agents: import is line 1"
assert_eq "" "$(sed -n 2p "$d/CLAUDE.md")" "agents: blank line 2"
assert_eq "$START" "$(sed -n 3p "$d/CLAUDE.md")" "agents: block from line 3"
cp "$d/CLAUDE.md" "$TMPDIR/agents-snap"
out="$(blk init "$d")"
assert_not_contains "$out" "NOTE=agents-md-imported" "agents: re-init edits, no note"
cmp -s "$d/CLAUDE.md" "$TMPDIR/agents-snap"; assert_eq 0 "$?" "agents: re-init byte-identical (one import line)"
assert_eq "" "$(cd "$d" && git status --porcelain)" "agents: status clean"
# .claude/AGENTS.md
d="$(make_git_fixture ss5)"
mkdir -p "$d/.claude"; printf '# Agents\n' > "$d/.claude/AGENTS.md"
out="$(blk init "$d")"
assert_contains "$out" "NOTE=agents-md-imported" "dot-claude agents: note"
assert_eq "@.claude/AGENTS.md" "$(sed -n 1p "$d/CLAUDE.md")" "dot-claude agents: import line"
# existing untracked CLAUDE.md is edited, never given an import
d="$(make_git_fixture ss5)"
printf '# Agents\n' > "$d/AGENTS.md"; printf 'mine\n' > "$d/CLAUDE.md"
out="$(blk init "$d")"
assert_not_contains "$out" "NOTE=agents-md-imported" "agents + existing CLAUDE.md: no note"
assert_eq "mine" "$(sed -n 1p "$d/CLAUDE.md")" "agents + existing CLAUDE.md: untouched head"
assert_not_contains "$(cat "$d/CLAUDE.md")" "@AGENTS.md" "agents + existing CLAUDE.md: no import"
# tracked CLAUDE.md -> new CLAUDE.local.md: AGENTS.md was not being read anyway, no import
d="$(make_git_fixture ss5)"
printf '# Agents\n' > "$d/AGENTS.md"; printf 'team\n' > "$d/CLAUDE.md"
(cd "$d" && git add AGENTS.md CLAUDE.md && git commit -q -m a --no-gpg-sign)
out="$(blk init "$d")"
assert_contains "$out" "TARGET=CLAUDE.local.md" "agents + tracked CLAUDE.md: local"
assert_not_contains "$out" "NOTE=agents-md-imported" "agents + tracked CLAUDE.md: no note"
assert_eq "$START" "$(sed -n 1p "$d/CLAUDE.local.md")" "agents + tracked CLAUDE.md: no import in local"
# .claude/CLAUDE.md present: AGENTS.md already shadowed, no import
d="$(make_git_fixture ss5)"
mkdir -p "$d/.claude"; printf '# Agents\n' > "$d/AGENTS.md"; printf 'x\n' > "$d/.claude/CLAUDE.md"
out="$(blk init "$d")"
assert_not_contains "$out" "NOTE=agents-md-imported" "agents + .claude/CLAUDE.md: no note"
assert_eq "$START" "$(sed -n 1p "$d/CLAUDE.md")" "agents + .claude/CLAUDE.md: no import"
# no AGENTS.md: no import, no note (covered above too)
d="$(make_git_fixture ss5)"
out="$(blk init "$d")"
assert_not_contains "$out" "NOTE=agents-md-imported" "no agents: no note"
assert_eq "$START" "$(sed -n 1p "$d/CLAUDE.md")" "no agents: block on line 1"

# --- #4: open upgrade-checklist items are shown in the block ---
CLLINE_PREFIX="Upgrade checklista:"
d="$(make_git_fixture upgrade-5-6)"
mkdir -p "$d/.claude"
cat > "$d/.claude/ss-upgrade-checklist.md" <<'CL'
# SilverStripe upgrade 5 → 6 — checklist (ss-version-aware)

## Faza 5→6
- [ ] M56-001 `app/a.php:2` — h (mapa: references/migrations/5-to-6.md#m56-001) — `x`
- [x] M56-002 `app/a.php:3` — h (mapa: references/migrations/5-to-6.md#m56-002) — `y`
- [ ] T-001 `app/b.php:9` — h (mapa: references/migrations/5-to-6.md#t-001) — `z`

## Ručni pregled (nema grep obrasca) — Faza 5→6
- [ ] M56-010 — Staro: a · Novo: b (mapa: references/migrations/5-to-6.md#m56-010)
- [x] M56-011 — Staro: a · Novo: b (mapa: references/migrations/5-to-6.md#m56-011)

<!-- ssva-state
5	M56-001	app/a.php	1	2	h	5-to-6	x
-->
CL
blk init "$d" >/dev/null
assert_file_contains "$d/CLAUDE.md" "Upgrade checklista: 2 otvorenih stavki (+1 za ručni pregled) — .claude/ss-upgrade-checklist.md"
n="$(block_lines "$d/CLAUDE.md")"
[ "$n" -le 15 ] && assert_eq 1 1 "checklist block <=15" || _fail "checklist block <=15" "<=15" "$n"
assert_eq "lock: " "$(grep -B1 -F -- "$END" "$d/CLAUDE.md" | head -n 1 | cut -c1-6)" "checklist: lock still last"
# only manual items open -> still shown
replace_in "$d/.claude/ss-upgrade-checklist.md" '^- \[ \] M56-001 `' '- [x] M56-001 `'
replace_in "$d/.claude/ss-upgrade-checklist.md" '^- \[ \] T-001 `' '- [x] T-001 `'
out="$(blk refresh "$d")"
assert_eq "CHANGED=1" "$out" "checklist progress: silent rewrite"
assert_file_contains "$d/CLAUDE.md" "Upgrade checklista: 0 otvorenih stavki (+1 za ručni pregled) — .claude/ss-upgrade-checklist.md"
# everything ticked -> line gone
replace_in "$d/.claude/ss-upgrade-checklist.md" '^- \[ \] M56-010 ' '- [x] M56-010 '
blk refresh "$d" >/dev/null
assert_not_contains "$(cat "$d/CLAUDE.md")" "$CLLINE_PREFIX" "all ticked: no checklist line"
# CRLF checklist counts the same
d="$(make_git_fixture upgrade-5-6)"; mkdir -p "$d/.claude"
printf '## Faza 5→6\r\n- [ ] M56-001 `a:1` — h (mapa: x) — `x`\r\n' > "$d/.claude/ss-upgrade-checklist.md"
assert_contains "$(blk show "$d")" "Upgrade checklista: 1 otvorenih stavki (+0 za ručni pregled) — .claude/ss-upgrade-checklist.md" "crlf checklist"
# no checklist -> no line
d="$(make_git_fixture upgrade-5-6)"
assert_not_contains "$(blk show "$d")" "$CLLINE_PREFIX" "no checklist: no line"
# real scanner output: counts match OPEN / MANUAL
d="$(make_git_fixture upgrade-5-6)"
sout="$("$SSVA_BASH" "$ROOT/plugins/ywli-dev/scripts/scan-upgrade.sh" --from 5 --to 6 --dir "$d" 2>/dev/null)"
so="$(printf '%s\n' "$sout" | sed -n 's/^OPEN=//p')"; sm="$(printf '%s\n' "$sout" | sed -n 's/^MANUAL=//p')"
assert_contains "$(blk show "$d")" "Upgrade checklista: $so otvorenih stavki (+$sm za ručni pregled) — .claude/ss-upgrade-checklist.md" "real scan counts"

finish
