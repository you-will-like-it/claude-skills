#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
SCAN="$ROOT/plugins/ywli-dev/scripts/scan-upgrade.sh"
PAT="$FIXTURES_DIR/scan/test.patterns"
MIG="$FIXTURES_DIR/scan/migrations"
exclude_file() { (cd "$1" && p="$(git rev-parse --git-path info/exclude)"; case "$p" in /*) echo "$p" ;; *) echo "$1/$p" ;; esac); }
last() { printf '%s\n' "$1" | tail -n 1; }
open_of() { printf '%s\n' "$1" | grep '^OPEN=' | tail -n 1; }
replace_in() { local t; t="$(mktemp "${TMPDIR:-/tmp}/ssr.XXXXXX")"; sed "s/$2/$3/g" "$1" > "$t" && mv "$t" "$1"; }
scan() { "$SSVA_BASH" "$SCAN" "$@" 2>/dev/null; }

[ -x "$SCAN" ] && assert_eq 1 1 "exec" || _fail "scan-upgrade.sh executable" "x" "not executable"

# --- usage / arg errors ---
assert_exit 2 "$SSVA_BASH" "$SCAN"
assert_exit 2 "$SSVA_BASH" "$SCAN" --from 5
assert_exit 2 "$SSVA_BASH" "$SCAN" --from 6 --to 5 --dir /tmp
assert_exit 2 "$SSVA_BASH" "$SCAN" --from 5 --to 5 --dir /tmp
assert_exit 2 "$SSVA_BASH" "$SCAN" --bogus

# --- first scan with --patterns ---
d="$(make_git_fixture scan)"
out="$(scan --patterns "$PAT" --dir "$d")"; rc=$?
assert_eq 1 "$rc" "open items -> exit 1"
assert_eq "OPEN=3" "$(last "$out")" "OPEN last line"
assert_contains "$out" "CHECKLIST=$d/.claude/ss-upgrade-checklist.md" "CHECKLIST line"
cl="$d/.claude/ss-upgrade-checklist.md"
body="$(cat "$cl")"
assert_not_contains "$body" "vendor/" "vendor ignored"
assert_not_contains "$body" "_resources" "_resources ignored"
assert_not_contains "$body" "node_modules" "node_modules ignored"
assert_not_contains "$body" ".yml" "glob limits to php"
assert_contains "$body" "## Faza test.patterns" "patterns title"
assert_contains "$body" '- [ ] T-001 `app/src/Page.php:2` — use ArrayData replacement (mapa: references/migrations/test.md#t-001) — `use ArrayData;`' "item format (patterns link + matched code)"
assert_eq "# SilverStripe upgrade" "$(head -n 1 "$cl" | cut -c1-22)" "title line"
assert_eq "" "$(sed -n 2p "$cl")" "blank after title"
assert_contains "$(cat "$(exclude_file "$d")")" "/.claude/ss-upgrade-checklist.md" "checklist excluded"
# tracked files untouched
assert_eq "" "$(cd "$d" && git status --porcelain --untracked-files=no)" "no tracked changes"

# --- deleted occurrence + shifted line ---
replace_in "$d/app/src/Other.php" "ArrayData in a comment" "nothing here"
printf '\n%s\n' "$(cat "$d/app/src/Page.php")" > "$d/app/src/Page.php.new" && mv "$d/app/src/Page.php.new" "$d/app/src/Page.php"
out="$(scan --patterns "$PAT" --dir "$d")"; rc=$?
assert_eq 1 "$rc" "still open"
assert_eq "OPEN=2" "$(last "$out")" "OPEN dropped by 1"
body="$(cat "$cl")"
assert_contains "$body" '- [x] T-001 `app/src/Other.php:2`' "deleted -> [x]"
assert_contains "$body" '- [ ] T-001 `app/src/Page.php:3`' "shifted line updated, still open"
assert_eq 3 "$(grep -c '^- \[' "$cl" | tr -d ' ')" "item count stable (no dupes)"

# --- reappearing key -> [ ] again ---
printf '<?php\n// ArrayData in a comment counts as a match\n' > "$d/app/src/Other.php"
out="$(scan --patterns "$PAT" --dir "$d")"
assert_eq "OPEN=3" "$(last "$out")" "reappeared -> open"
assert_contains "$(cat "$cl")" '- [ ] T-001 `app/src/Other.php:2`' "reappeared item open"

# --- all fixed ---
printf '<?php\n' > "$d/app/src/Other.php"
printf '<?php\n' > "$d/app/src/Page.php"
out="$(scan --patterns "$PAT" --dir "$d")"; rc=$?
assert_eq 0 "$rc" "all fixed -> exit 0"
assert_eq "OPEN=0" "$(last "$out")" "OPEN=0"
assert_eq 0 "$(grep -c '^- \[ \]' "$cl" | tr -d ' ')" "no open items"
assert_eq 3 "$(grep -c '^- \[x\]' "$cl" | tr -d ' ')" "three closed items"

# --- identical lines: ordinal ---
d2="$(make_git_fixture scan)"
printf '<?php\nnew ArrayData();\nnew ArrayData();\n' > "$d2/app/src/Other.php"
out="$(scan --patterns "$PAT" --dir "$d2")"
assert_eq "OPEN=4" "$(last "$out")" "dup lines each counted"
printf '<?php\nnew ArrayData();\n' > "$d2/app/src/Other.php"
out="$(scan --patterns "$PAT" --dir "$d2")"
assert_eq "OPEN=3" "$(last "$out")" "one of two identical closed"
assert_eq 1 "$(grep -c '^- \[x\]' "$d2/.claude/ss-upgrade-checklist.md" | tr -d ' ')" "ordinal 2 closed"

# --- multiple globs ---
d3="$(make_git_fixture scan)"
out="$(scan --patterns "$FIXTURES_DIR/scan/multi.patterns" --dir "$d3")"
assert_eq "OPEN=2" "$(last "$out")" "yml + ss matched"
assert_contains "$(cat "$d3/.claude/ss-upgrade-checklist.md")" 'app/_config/app.yml:2' "yml hit"
assert_contains "$(cat "$d3/.claude/ss-upgrade-checklist.md")" 'themes/x/templates/Page.ss:1' "ss hit"

# --- --no-exclude ---
d4="$(make_git_fixture scan)"
scan --patterns "$PAT" --dir "$d4" --no-exclude >/dev/null
assert_not_contains "$(cat "$(exclude_file "$d4")")" "ss-upgrade-checklist" "no-exclude honoured"
# custom checklist path
scan --patterns "$PAT" --dir "$d4" --checklist "$d4/custom.md" >/dev/null
[ -f "$d4/custom.md" ] && assert_eq 1 1 "custom" || _fail "custom checklist" "exists" "missing"

# --- outside git: no error, no exclude ---
d5="$(mktemp -d "${TMPDIR:-/tmp}/ssnogit.XXXXXX")"; cp -R "$FIXTURES_DIR/scan/." "$d5/"
out="$(scan --patterns "$PAT" --dir "$d5")"; rc=$?
assert_eq 1 "$rc" "no-git works"
assert_eq "OPEN=3" "$(last "$out")" "no-git count"

# --- bad regex ---
d6="$(make_git_fixture scan)"
err="$("$SSVA_BASH" "$SCAN" --patterns "$FIXTURES_DIR/scan/bad.patterns" --dir "$d6" 2>&1 >/dev/null)"; rc=$?
assert_eq 2 "$rc" "bad regex exit 2"
assert_contains "$err" "BAD-001" "bad regex names ID"

# --- chain: lock 4 -> phase 5->6 locked ---
d7="$(make_git_fixture scan)"
out="$(SSVA_MIGRATIONS_DIR="$MIG" scan --from 4 --to 6 --dir "$d7")"; rc=$?
body="$(cat "$d7/.claude/ss-upgrade-checklist.md")"
assert_contains "$body" "## Faza 4→5" "phase 4->5 header"
assert_contains "$body" "## Faza 5→6 (zaključano dok lock ne pokaže 5.x)" "locked header"
assert_not_contains "$body" "M56-001" "locked phase lists nothing"
assert_contains "$body" '- [ ] M45-001 `app/src/Page.php:2` — four to five (mapa: references/migrations/4-to-5.md#m45-001) — `use ArrayData;`' "chain item"
assert_eq "OPEN=3" "$(last "$out")" "only unlocked phase counted"
assert_eq 1 "$rc" "open in unlocked phase"
assert_contains "$body" "# SilverStripe upgrade 4 → 6 — checklist (ss-version-aware)" "chain title"

# --- chain: lock 5 -> both unlocked; installed.json overrides lock ---
d8="$(make_git_fixture scan)"
replace_in "$d8/composer.lock" '4\.13\.0' '5.4.0'
out="$(SSVA_MIGRATIONS_DIR="$MIG" scan --from 4 --to 6 --dir "$d8")"
body="$(cat "$d8/.claude/ss-upgrade-checklist.md")"
assert_contains "$body" 'M56-001 `app/_config/app.yml:2`' "phase 5->6 unlocked at 5.x"
assert_eq "OPEN=4" "$(last "$out")" "both phases counted"
mkdir -p "$d8/vendor/composer"
printf '{\n "packages": [\n  {\n   "name": "silverstripe/framework",\n   "version": "4.13.1"\n  }\n ]\n}\n' > "$d8/vendor/composer/installed.json"
out="$(SSVA_MIGRATIONS_DIR="$MIG" scan --from 4 --to 6 --dir "$d8")"
assert_contains "$(cat "$d8/.claude/ss-upgrade-checklist.md")" "zaključano dok lock ne pokaže 5.x" "installed major wins"

# --- missing map -> exit 2 ---
err="$(SSVA_MIGRATIONS_DIR="$MIG" "$SSVA_BASH" "$SCAN" --from 3 --to 4 --dir "$d7" 2>&1 >/dev/null)"; rc=$?
assert_eq 2 "$rc" "missing map exit 2"
assert_contains "$err" "no migration map for 3→4" "missing map message"

# --- F1: backslashes in hints survive verbatim and rescans are stable ---
d9="$(make_git_fixture scan)"
printf 'P-1\tArrayData\t*.php\tUse \\SilverStripe\\ORM\\DataObject and \\newline \\tab \\b\n' > "$d9/bs.patterns"
out="$(scan --patterns "$d9/bs.patterns" --dir "$d9")"
assert_eq "OPEN=3" "$(last "$out")" "backslash hint open count"
assert_contains "$(cat "$d9/.claude/ss-upgrade-checklist.md")" '— Use \SilverStripe\ORM\DataObject and \newline \tab \b (mapa: references/migrations/bs.md#p-1)' "hint verbatim"
out="$(scan --patterns "$d9/bs.patterns" --dir "$d9")"; out="$(scan --patterns "$d9/bs.patterns" --dir "$d9")"
assert_eq "OPEN=3" "$(last "$out")" "stable after rescans"
assert_contains "$(cat "$d9/.claude/ss-upgrade-checklist.md")" '— Use \SilverStripe\ORM\DataObject and \newline \tab \b (mapa' "hint verbatim after rescans"
assert_eq 3 "$(grep -c '^- \[' "$d9/.claude/ss-upgrade-checklist.md" | tr -d ' ')" "no extra items"

# --- F2: colon in file name ---
d10="$(make_git_fixture scan)"
printf '<?php\nnew ArrayData();\n' > "$d10/app/src/c:d.php"
scan --patterns "$PAT" --dir "$d10" >/dev/null
assert_contains "$(cat "$d10/.claude/ss-upgrade-checklist.md")" '`app/src/c:d.php:2`' "colon filename relpath+line"

# --- F3: strict 4-field pattern lines ---
d11="$(make_git_fixture scan)"
printf 'X-1\tArrayData\t*.php\n' > "$d11/three.patterns"
err="$("$SSVA_BASH" "$SCAN" --patterns "$d11/three.patterns" --dir "$d11" 2>&1 >/dev/null)"; rc=$?
assert_eq 2 "$rc" "3 fields exit 2"
assert_contains "$err" "line 1" "names line number"
printf '# c\nX-1\tArrayData\t\tempty globs hint\n' > "$d11/empty.patterns"
err="$("$SSVA_BASH" "$SCAN" --patterns "$d11/empty.patterns" --dir "$d11" 2>&1 >/dev/null)"; rc=$?
assert_eq 0 "$((rc==2?1:0))" "empty globs field is 4 fields, not a parse error"

# --- state block deleted: no crash, findings open ---
d12="$(make_git_fixture scan)"
scan --patterns "$PAT" --dir "$d12" >/dev/null
printf '<?php\n' > "$d12/app/src/Other.php"
scan --patterns "$PAT" --dir "$d12" >/dev/null
cl12="$d12/.claude/ss-upgrade-checklist.md"
awk '/^<!-- ssva-state/{exit} {print}' "$cl12" > "$cl12.t" && mv "$cl12.t" "$cl12"
out="$(scan --patterns "$PAT" --dir "$d12")"; rc=$?
assert_eq 1 "$rc" "no-state rescan exit"
assert_eq "OPEN=2" "$(last "$out")" "no-state rescan lists findings as open"
assert_eq 0 "$(grep -c '^- \[x\]' "$cl12" | tr -d ' ')" "closed history lost"


# --- lang/ (i18n YAML keyed by FQCN, valid in every version) is excluded ---
dl="$(mktemp -d "${TMPDIR:-/tmp}/sslang.XXXXXX")"
mkdir -p "$dl/app/src" "$dl/lang" "$dl/app/lang"
printf '<?php\nuse SilverStripe\\ORM\\ValidationException;\n' > "$dl/app/src/A.php"
printf 'en:\n  SilverStripe\\ORM\\ValidationException:\n    X: y\n' > "$dl/lang/en.yml"
cp "$dl/lang/en.yml" "$dl/app/lang/de.yml"
pl="$dl/l.patterns"
printf 'L-001\tSilverStripe\\\\ORM\\\\ValidationException\t*.php,*.yml\thint\n' > "$pl"
out="$(scan --patterns "$pl" --dir "$dl" --no-exclude)"
assert_eq "OPEN=1" "$(last "$out")" "lang/ hits not counted"
body="$(cat "$dl/.claude/ss-upgrade-checklist.md")"
assert_contains "$body" "app/src/A.php:2" "app code still scanned"
assert_not_contains "$body" "lang/" "lang/ ignored (root and module)"
rm -rf "$dl"

# --- manual-review section: map entries without a pattern ---
MM="$(mktemp -d "${TMPDIR:-/tmp}/ssmm.XXXXXX")"
TAB="$(printf '\t')"
cat > "$MM/4-to-5.md" <<'MAP'
# Map 4→5
## Premješteno
### M45-001
**Staro:** `Old\Foo` · **Novo:** `New\Foo` · **Vrsta:** premješteno
Izvor: https://docs.silverstripe.org/en/5/
### M45-002
**Staro:** `$First` u templatu · **Novo:** `$IsFirst` · **Vrsta:** template
Izvor: https://docs.silverstripe.org/en/5/
Napomena: nema grep obrasca.
MAP
printf 'M45-001%sOld\\\\Foo%s*.php%sOld\\Foo -> New\\Foo\n' "$TAB" "$TAB" "$TAB" > "$MM/4-to-5.patterns"
cat > "$MM/5-to-6.md" <<'MAP'
# Map 5→6
### M56-001
**Staro:** `Bar` · **Novo:** `Baz` · **Vrsta:** premješteno
Izvor: https://docs.silverstripe.org/en/6/
### M56-002
**Staro:** `a --> b` with `x\y` · **Novo:** — (uklonjeno bez zamjene) · **Vrsta:** uklonjeno
Izvor: https://docs.silverstripe.org/en/6/
### M56-003
**Staro:** scaffolding · **Novo:** drugačija polja · **Vrsta:** ostalo
Izvor: https://docs.silverstripe.org/en/6/
MAP
printf 'M56-001%s\\bBar\\b%s*.php%sBar -> Baz\n' "$TAB" "$TAB" "$TAB" > "$MM/5-to-6.patterns"
# project on 5.x
dm="$(mktemp -d "${TMPDIR:-/tmp}/ssdm.XXXXXX")"; mkdir -p "$dm/app"
printf '<?php\n$x = new Bar();\n' > "$dm/app/x.php"
printf '{\n    "packages": [\n        {\n            "name": "silverstripe/framework",\n            "version": "5.4.3"\n        }\n    ]\n}\n' > "$dm/composer.lock"
out="$(SSVA_MIGRATIONS_DIR="$MM" scan --from 5 --to 6 --dir "$dm")"; rc=$?
clm="$dm/.claude/ss-upgrade-checklist.md"; body="$(cat "$clm")"
assert_eq 1 "$rc" "exit 1: one open pattern item"
assert_contains "$body" "## Ručni pregled (nema grep obrasca) — Faza 5→6" "manual section heading"
assert_contains "$body" '- [ ] M56-002 — Staro: `a --@> b` with `x\y` · Novo: — (uklonjeno bez zamjene) (mapa: references/migrations/5-to-6.md#m56-002)' "manual item format (escaped -->, backslash kept)"
assert_contains "$body" '- [ ] M56-003 — Staro: scaffolding · Novo: drugačija polja (mapa: references/migrations/5-to-6.md#m56-003)' "manual item 2"
assert_not_contains "$body" "M56-001 —" "entry with pattern not listed as manual"
assert_contains "$body" '- [ ] M56-001 `app/x.php:2`' "pattern item still listed"
assert_eq "CHECKLIST=$clm" "$(printf '%s\n' "$out" | head -n 1)" "CHECKLIST first"
assert_eq "MANUAL=2" "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" "MANUAL right before OPEN"
assert_eq "OPEN=1" "$(last "$out")" "OPEN last, manual not counted"
# tick one manual item by hand; rescans keep it
t="$(mktemp "${TMPDIR:-/tmp}/sst.XXXXXX")"
sed 's/^- \[ \] M56-003 — /- [x] M56-003 — /' "$clm" > "$t" && cat "$t" > "$clm"; rm -f "$t"
out="$(SSVA_MIGRATIONS_DIR="$MM" scan --from 5 --to 6 --dir "$dm")"
body="$(cat "$clm")"
assert_contains "$body" "- [x] M56-003 — Staro: scaffolding" "manual tick preserved"
assert_contains "$body" "- [ ] M56-002 — " "unticked manual stays open"
assert_eq "MANUAL=1" "$(printf '%s\n' "$out" | grep '^MANUAL=')" "MANUAL counts unticked only"
assert_eq "OPEN=1" "$(last "$out")" "OPEN unaffected by manual ticks"
out="$(SSVA_MIGRATIONS_DIR="$MM" scan --from 5 --to 6 --dir "$dm")"
assert_contains "$(cat "$clm")" "- [x] M56-003 — " "tick survives a second rescan"
assert_eq 1 "$(grep -c '^<!-- ssva-state$' "$clm" | tr -d ' ')" "one state block"
# fix the pattern item: OPEN=0, exit 0, although manual items remain
printf '<?php\n$x = new Baz();\n' > "$dm/app/x.php"
out="$(SSVA_MIGRATIONS_DIR="$MM" scan --from 5 --to 6 --dir "$dm")"; rc=$?
assert_eq 0 "$rc" "exit 0 with OPEN=0 despite open manual items"
assert_eq "OPEN=0" "$(last "$out")" "OPEN=0 last"
assert_eq "MANUAL=1" "$(printf '%s\n' "$out" | grep '^MANUAL=')" "MANUAL still reported"
assert_contains "$(cat "$clm")" '- [x] M56-001 `app/x.php:2`' "closed pattern item kept in state"
# locked phase: 4→6 with lock on 4.x -> 5→6 manual section not listed
dl4="$(mktemp -d "${TMPDIR:-/tmp}/ssl4.XXXXXX")"; mkdir -p "$dl4/app"; printf '<?php\n' > "$dl4/app/x.php"
printf '{\n    "packages": [\n        {\n            "name": "silverstripe/framework",\n            "version": "4.13.10"\n        }\n    ]\n}\n' > "$dl4/composer.lock"
out="$(SSVA_MIGRATIONS_DIR="$MM" scan --from 4 --to 6 --dir "$dl4")"
cl4="$dl4/.claude/ss-upgrade-checklist.md"; body="$(cat "$cl4")"
assert_contains "$body" "## Ručni pregled (nema grep obrasca) — Faza 4→5" "unlocked phase manual section"
assert_contains "$body" '- [ ] M45-002 — Staro: `$First` u templatu · Novo: `$IsFirst` (mapa: references/migrations/4-to-5.md#m45-002)' "4→5 manual item"
assert_not_contains "$body" "Ručni pregled (nema grep obrasca) — Faza 5→6" "locked phase manual section absent"
assert_not_contains "$body" "M56-002" "locked phase manual items absent"
assert_eq "MANUAL=1" "$(printf '%s\n' "$out" | grep '^MANUAL=')" "MANUAL counts unlocked phases only"
# order in the file: phase items, its manual section, then the next phase
ln_faza="$(grep -n '^## Faza 4→5$' "$cl4" | cut -d: -f1)"
ln_man="$(grep -n '^## Ručni pregled (nema grep obrasca) — Faza 4→5$' "$cl4" | cut -d: -f1)"
ln_f56="$(grep -n '^## Faza 5→6' "$cl4" | cut -d: -f1)"
if [ -n "$ln_faza" ] && [ -n "$ln_man" ] && [ -n "$ln_f56" ] && [ "$ln_faza" -lt "$ln_man" ] && [ "$ln_man" -lt "$ln_f56" ]; then
  assert_eq 1 1 "section order"
else
  _fail "section order" "Faza 4→5 < Ručni 4→5 < Faza 5→6" "$ln_faza $ln_man $ln_f56"
fi
# --patterns mode without a matching .md: no manual section, MANUAL=0
dz="$(mktemp -d "${TMPDIR:-/tmp}/ssz.XXXXXX")"; mkdir -p "$dz/app"; printf '<?php\n' > "$dz/app/x.php"
out="$(scan --patterns "$PAT" --dir "$dz")"
assert_not_contains "$(cat "$dz/.claude/ss-upgrade-checklist.md")" "Ručni pregled" "no .md -> no manual section"
assert_eq "MANUAL=0" "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" "MANUAL=0 without map, before OPEN"
rm -rf "$MM" "$dm" "$dz" "$dl4"

# --- #7: matched code shown on each item; backticks and long/multibyte lines handled ---
dc="$(make_git_fixture scan)"
printf '<?php\n$a = `ArrayData`; $b = ``x``;\n' > "$dc/app/src/Tick.php"
long="$(i=0; while [ $i -lt 30 ]; do printf 'abc'; i=$((i+1)); done)"
printf '<?php\n$x = new ArrayData(); // %s\n' "$long" > "$dc/app/src/Long.php"
mb="$(i=0; while [ $i -lt 40 ]; do printf 'čć'; i=$((i+1)); done)"
printf '<?php\nArrayData %s\n' "$mb" > "$dc/app/src/Mb.php"
scan --patterns "$PAT" --dir "$dc" >/dev/null
cl="$dc/.claude/ss-upgrade-checklist.md"
assert_contains "$(cat "$cl")" '`app/src/Tick.php:2` — use ArrayData replacement (mapa: references/migrations/test.md#t-001) — ``` $a = `ArrayData`; $b = ``x``; ```' "backticks: fence longer than the longest run"
lline="$(grep -F '`app/src/Long.php:2`' "$cl")"
code="${lline#*#t-001) — \`}"; code="${code%\`}"
assert_eq 80 "$(printf '%s' "$code" | LC_ALL=C wc -c | tr -d ' ')" "long line truncated to 80 bytes"
assert_contains "$code" '$x = new ArrayData(); // abcabc' "truncated code keeps its start"
assert_eq "..." "$(printf '%s' "$code" | LC_ALL=C tail -c 3)" "truncation marked with ..."
mline="$(grep -F '`app/src/Mb.php:2`' "$cl")"
printf '%s\n' "$mline" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; assert_eq 0 "$?" "multibyte truncation keeps valid UTF-8"
# the merge key is unchanged: a rescan keeps the same items (no duplicates, nothing closed)
n1="$(grep -c '^- \[' "$cl" | tr -d ' ')"
out="$(scan --patterns "$PAT" --dir "$dc")"
assert_eq "$n1" "$(grep -c '^- \[' "$cl" | tr -d ' ')" "rescan: same item count"
assert_eq 0 "$(grep -c '^- \[x\]' "$cl" | tr -d ' ')" "rescan: nothing closed"
assert_contains "$(cat "$cl")" '`app/src/Page.php:2` — use ArrayData replacement (mapa: references/migrations/test.md#t-001) — `use ArrayData;`' "rescan: code still shown"

# --- #6: .claude (worktrees), silverstripe-cache and .ddev are skipped ---
dx="$(make_git_fixture scan)"
mkdir -p "$dx/.claude/worktrees/wt/app/src" "$dx/silverstripe-cache/x" "$dx/app/silverstripe-cache" "$dx/.ddev/homeadditions"
cp "$dx/app/src/Page.php" "$dx/.claude/worktrees/wt/app/src/Page.php"
cp "$dx/app/src/Page.php" "$dx/silverstripe-cache/x/c.php"
cp "$dx/app/src/Page.php" "$dx/app/silverstripe-cache/c.php"
cp "$dx/app/src/Page.php" "$dx/.ddev/homeadditions/h.php"
out="$(scan --patterns "$PAT" --dir "$dx")"
assert_eq "OPEN=3" "$(last "$out")" "skipped dirs add no items"
body="$(cat "$dx/.claude/ss-upgrade-checklist.md")"
assert_not_contains "$body" ".claude/worktrees" ".claude skipped"
assert_not_contains "$body" "silverstripe-cache" "silverstripe-cache skipped"
assert_not_contains "$body" ".ddev/" ".ddev skipped"

finish
