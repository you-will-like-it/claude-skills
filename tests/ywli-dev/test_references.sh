#!/usr/bin/env bash
# Validates skills/ss-version-aware/references/**: sources on every map entry and version-reference
# table row, .patterns <-> .md ID consistency, 4-field pattern lines, compilable ERE regexes.
# The checkers are first run on a broken fixture (must catch every planted error), then on the real tree.
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
REFS="$ROOT/plugins/ywli-dev/skills/ss-version-aware/references"
HOSTS='https://(docs\.silverstripe\.org|api\.silverstripe\.org|github\.com/silverstripe)/'

# check_entries <md>: every "### M<nn>-<nnn>" needs an "Izvor: <allowed-host URL>" line (URL right after
# "Izvor: ") before the next heading. Also flags duplicate IDs and malformed "### M<digit>..." headings.
# Prints one "ERROR ..." line per problem.
check_entries() {
  SSVA_HOSTS="$HOSTS" awk -v f="$1" '
    BEGIN { hosts = ENVIRON["SSVA_HOSTS"] }
    function close_entry() { if (id != "" && !ok) printf "ERROR %s: %s has no Izvor: line with an allowed host\n", f, id; id = "" }
    { sub(/\r$/, "") }
    /^#/ {
      close_entry()
      if ($0 ~ /^### M[0-9]/ && $0 !~ /^### M[0-9][0-9]-[0-9][0-9][0-9][ ]*$/) printf "ERROR %s: malformed entry heading: %s\n", f, $0
      if ($0 ~ /^### M[0-9][0-9]-[0-9][0-9][0-9][ ]*$/) {
        id = $2; ok = 0
        if (id in seen) printf "ERROR %s: duplicate entry %s\n", f, id
        seen[id] = 1
      }
      next
    }
    id != "" && $0 ~ ("^Izvor: " hosts) { ok = 1 }
    END { close_entry() }' "$1"
}

# check_tables <md>: every table data row (not header, not |---| separator) has an allowed-host URL
# that starts a token (line start, space, "|", "(" or "<"), so a URL embedded in another URL does not count.
check_tables() {
  SSVA_HOSTS="$HOSTS" awk -v f="$1" '
    BEGIN { hosts = ENVIRON["SSVA_HOSTS"] }
    function flush() { if (pend != "" && pend !~ ("(^|[[:space:]|(<])" hosts)) printf "ERROR %s:%d: table row without allowed source URL\n", f, pl; pend = "" }
    { sub(/\r$/, "") }
    /^[ ]*\|/ {
      if ($0 ~ /^[ ]*\|[ :|-]+\|?[ ]*$/ && $0 ~ /-/) { pend = ""; next }   # separator: pending row was the header
      flush(); pend = $0; pl = NR; next
    }
    { flush() }
    END { flush() }' "$1"
}

# check_patterns <patterns>: 4 tab fields, compilable regex, each ID has "### ID" in the same-named .md.
# Reverse direction (map entry without pattern) is printed as WARN.
check_patterns() {
  local pf="$1" md="${1%.patterns}.md" id re
  if [ ! -f "$md" ]; then echo "ERROR $pf: no matching map $md"; return; fi
  tr -d '\r' < "$pf" | awk -F'\t' -v f="$pf" '
    /^[ ]*$/ || /^#/ { next }
    NF != 4 { printf "ERROR %s:%d: expected 4 tab-separated fields, got %d\n", f, NR, NF; next }
    $1 in seen { printf "ERROR %s:%d: duplicate pattern ID %s\n", f, NR, $1 }
    { seen[$1] = 1 }'
  tr -d '\r' < "$pf" | awk -F'\t' '/^[ ]*$/ || /^#/ { next } NF == 4 { print $1 "\t" $2 }' |
  while IFS="$(printf '\t')" read -r id re; do
    grep -E -e "$re" /dev/null >/dev/null 2>&1
    [ $? -eq 2 ] && echo "ERROR $pf: $id: regex does not compile: $re"
    tr -d '\r' < "$md" | grep -qxE "### $id[ ]*" || echo "ERROR $pf: $id has no '### $id' heading in $(basename "$md")"
  done
  tr -d '\r' < "$md" | sed -n 's/^### \(M[0-9][0-9]-[0-9][0-9][0-9]\)[ ]*$/\1/p' | while read -r id; do
    tr -d '\r' < "$pf" | cut -f1 | grep -qxF "$id" || echo "WARN $md: $id has no pattern (not greppable?)"
  done
}

# check_tree <refs dir>: all checks over every .md / .patterns below it. Results travel as output lines
# (ERROR/WARN), so the while-loop subshells need no exit-status propagation; paths may contain spaces.
check_tree() {
  find "$1" -type f -name '*.md' | sort | while IFS= read -r f; do
    check_entries "$f"
    case "$(basename "$f")" in ss*.md) check_tables "$f" ;; esac
  done
  find "$1" -type f -name '*.patterns' | sort | while IFS= read -r f; do check_patterns "$f"; done
}

# Version references (ss<N>.md) that must exist.
REQUIRED_VERSION_REFS="ss3 ss4 ss5 ss6"
# The six H2 sections every ss<N>.md has, exactly once each and in this order ("|"-separated).
# Hard size cap per ss<N>.md (loaded into context on every activation).
MAX_REF_LINES=350
SECTIONS='## Osnovno|## Namespace-ovi i klase|## Potpisi i obrasci|## Config/YAML|## Templati|## Česte greške'

# check_version_ref <ss<N>.md>: exactly one H1 "# SilverStripe <N> — referenca (ss-version-aware)" (N from the
# file name), exactly the six H2 headings of $SECTIONS in order, no others, and at most $MAX_REF_LINES lines.
# Lines inside ``` fences are ignored.
check_version_ref() {
  local n
  n="$(basename "$1" | sed -n 's/^ss\([0-9][0-9]*\)\.md$/\1/p')"
  [ "$(wc -l < "$1" | tr -d ' ')" -le "$MAX_REF_LINES" ] || echo "ERROR $1: more than $MAX_REF_LINES lines ($(wc -l < "$1" | tr -d ' '))"
  SSVA_SECTIONS="$SECTIONS" awk -v f="$1" -v n="$n" '
    BEGIN { ns = split(ENVIRON["SSVA_SECTIONS"], want, "|"); h1 = "# SilverStripe " n " — referenca (ss-version-aware)" }
    { sub(/\r$/, "") }
    /^```/ { fence = !fence; next }
    fence { next }
    /^# / { h1n++; if ($0 != h1) printf "ERROR %s:%d: unexpected H1: %s\n", f, NR, $0; next }
    /^## / { k++; got[k] = $0 }
    END {
      if (h1n == 0) printf "ERROR %s: no H1 title\n", f
      if (h1n > 1) printf "ERROR %s: %d H1 titles\n", f, h1n
      if (k != ns) printf "ERROR %s: expected %d H2 sections, found %d\n", f, ns, k
      m = (k > ns) ? k : ns
      for (i = 1; i <= m; i++) if (got[i] != want[i]) {
        printf "ERROR %s: H2 #%d is \"%s\", expected \"%s\"\n", f, i, got[i], want[i]; break
      }
    }' "$1"
}

errors_of() { printf '%s\n' "$1" | grep -c '^ERROR' | tr -d ' '; }

# --- self-test: the checkers must catch planted errors ---
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ssref.XXXXXX")"
mkdir -p "$TMP/migrations"
TAB="$(printf '\t')"
cat > "$TMP/migrations/9-to-10.md" <<'EOF'
# Map
### M90-001
**Staro:** `A` · **Novo:** `B` · **Vrsta:** premješteno
Izvor: https://docs.silverstripe.org/en/6/changelogs/6.0.0/
### M90-002
**Staro:** `A` · **Novo:** `B` · **Vrsta:** uklonjeno
Izvor: https://example.com/not-allowed/
### M90-003
**Staro:** `A` · **Novo:** `B` · **Vrsta:** config
## Next section
Izvor: https://docs.silverstripe.org/en/6/
### M90-004
Izvor: https://github.com/silverstripe-evil/x/
### M90-001
Izvor: https://github.com/silverstripe/silverstripe-framework/blob/6/src/Core/Path.php
### M90-005
Izvor: https://api.silverstripe.org/6/
### M90-006
Izvor: https://evil.example/?u=https://docs.silverstripe.org/en/6/
### M9-001
Izvor: https://docs.silverstripe.org/en/6/
### M90-01
Izvor: https://docs.silverstripe.org/en/6/
### M90-007
Vidi Izvor: https://docs.silverstripe.org/en/6/
### Middleware notes
EOF
mkdir -p "$TMP/sub dir"
printf '### M91-001\nno source here\n' > "$TMP/sub dir/with space.md"
{
  printf '# comment\n'
  printf 'M90-001%s\\bArrayData\\b%s*.php%shint\n' "$TAB" "$TAB" "$TAB"
  printf 'M90-002%s(unclosed%s*.php%shint\n' "$TAB" "$TAB" "$TAB"
  printf 'M90-099%sfoo%s*.php%shint\n' "$TAB" "$TAB" "$TAB"
  printf 'M90-00%sfoo%s*.php%shint\n' "$TAB" "$TAB" "$TAB"
  printf 'M90-003%sfoo%s*.php\n' "$TAB" "$TAB"
} > "$TMP/migrations/9-to-10.patterns"
cat > "$TMP/ss9.md" <<'EOF'
# SS9
| Klasa | Namespace | Izvor |
|---|:--|---|
| ArrayData | SilverStripe\Model | https://github.com/silverstripe/silverstripe-framework/blob/6/src/Model/ArrayData.php |
| ArrayList | SilverStripe\Model\List | none |
| Map | x | https://evil.example/https://docs.silverstripe.org/en/6/ |
| GroupedList | x | [docs](https://docs.silverstripe.org/en/6/) |
| ListDecorator | x |https://docs.silverstripe.org/en/6/|
EOF
out="$(check_tree "$TMP")"
assert_contains "$out" "M90-002 has no Izvor" "self-test: disallowed host"
assert_contains "$out" "M90-003 has no Izvor" "self-test: Izvor after next heading does not count"
assert_contains "$out" "M90-004 has no Izvor" "self-test: lookalike github org rejected"
assert_contains "$out" "duplicate entry M90-001" "self-test: duplicate entry"
assert_not_contains "$out" "M90-005 has no Izvor" "self-test: api host allowed"
assert_contains "$out" "M90-002: regex does not compile" "self-test: bad regex"
assert_contains "$out" "M90-099 has no '### M90-099' heading" "self-test: pattern ID without heading"
assert_contains "$out" "expected 4 tab-separated fields, got 3" "self-test: 3-field line"
assert_contains "$out" "WARN $TMP/migrations/9-to-10.md: M90-004 has no pattern" "self-test: reverse is a warning"
assert_contains "$out" "ss9.md:5: table row without allowed source URL" "self-test: table data row"
assert_not_contains "$out" "ss9.md:2:" "self-test: header row skipped"
assert_not_contains "$out" "ss9.md:4:" "self-test: sourced row ok"
assert_contains "$out" "M90-006 has no Izvor" "self-test: allowed host must follow 'Izvor: ' directly"
assert_contains "$out" "malformed entry heading: ### M9-001" "self-test: 1-digit map prefix rejected"
assert_contains "$out" "malformed entry heading: ### M90-01" "self-test: 2-digit entry number rejected"
assert_not_contains "$out" "Middleware notes" "self-test: ordinary ### M... heading not an entry"
assert_contains "$out" "with space.md: M91-001 has no Izvor" "self-test: paths with spaces are checked"
assert_contains "$out" "ss9.md:6: table row without allowed source URL" "self-test: URL embedded in another URL rejected"
assert_not_contains "$out" "ss9.md:7:" "self-test: markdown link to allowed host ok"
assert_contains "$out" "M90-007 has no Izvor" "self-test: 'Izvor:' must start the line"
assert_not_contains "$out" "ss9.md:8:" "self-test: URL directly after '|' is a token start"
assert_contains "$out" "M90-00 has no '### M90-00' heading" "self-test: pattern ID must match a whole heading"
assert_eq 15 "$(errors_of "$out")" "self-test: exact error count"

# --- self-test: version-reference structure (mutants of a valid ss9.md) ---
V="$TMP/vref"; mkdir -p "$V/good" "$V/crlf" "$V/fence" "$V/order" "$V/missing" "$V/dup" "$V/extra" "$V/noh1" "$V/badh1" "$V/twoh1"
good_ref() { # good_ref <N>
  printf '# SilverStripe %s — referenca (ss-version-aware)\n\nUvod.\n' "$1"
  printf '%s\n' "$SECTIONS" | tr '|' '\n' | while IFS= read -r h; do printf '\n%s\n\ntekst\n' "$h"; done
}
good_ref 9 > "$V/good/ss9.md"
good_ref 9 | awk '{ printf "%s\r\n", $0 }' > "$V/crlf/ss9.md"
{ good_ref 9; printf '```yaml\n## not a heading\n# nor this\n```\n'; } > "$V/fence/ss9.md"
good_ref 9 | sed -e 's/^## Templati$/## TMP/' -e 's/^## Config\/YAML$/## Templati/' -e 's/^## TMP$/## Config\/YAML/' > "$V/order/ss9.md"
good_ref 9 | grep -v '^## Templati$' > "$V/missing/ss9.md"
{ good_ref 9; printf '\n## Osnovno\n'; } > "$V/dup/ss9.md"
{ good_ref 9; printf '\n## Dodatak\n'; } > "$V/extra/ss9.md"
good_ref 9 | grep -v '^# ' > "$V/noh1/ss9.md"
good_ref 8 > "$V/badh1/ss9.md"
{ good_ref 9; printf '\n# SilverStripe 9 — referenca (ss-version-aware)\n'; } > "$V/twoh1/ss9.md"
for d in good crlf fence; do
  assert_eq "" "$(check_version_ref "$V/$d/ss9.md")" "self-test vref: $d is valid"
done
assert_contains "$(check_version_ref "$V/order/ss9.md")" 'H2 #4 is "## Templati", expected "## Config/YAML"' "self-test vref: order"
assert_contains "$(check_version_ref "$V/missing/ss9.md")" "expected 6 H2 sections, found 5" "self-test vref: missing section"
assert_contains "$(check_version_ref "$V/dup/ss9.md")" 'H2 #7 is "## Osnovno"' "self-test vref: duplicate section"
assert_contains "$(check_version_ref "$V/extra/ss9.md")" "expected 6 H2 sections, found 7" "self-test vref: extra section"
assert_contains "$(check_version_ref "$V/noh1/ss9.md")" "no H1 title" "self-test vref: missing H1"
assert_contains "$(check_version_ref "$V/badh1/ss9.md")" "unexpected H1: # SilverStripe 8" "self-test vref: H1 major must match file"
assert_contains "$(check_version_ref "$V/twoh1/ss9.md")" "2 H1 titles" "self-test vref: single H1"
mkdir -p "$V/long"; { good_ref 9; i=0; while [ $i -lt 350 ]; do echo x; i=$((i+1)); done; } > "$V/long/ss9.md"
assert_contains "$(check_version_ref "$V/long/ss9.md")" "more than 350 lines" "self-test vref: line cap"

# --- the real references ---
for f in migrations/5-to-6.md migrations/5-to-6.patterns migrations/4-to-5.md migrations/4-to-5.patterns; do
  _ASSERTS=$((_ASSERTS+1))
  [ -f "$REFS/$f" ] || _fail "required reference file" "$REFS/$f exists" "missing"
done
for v in $REQUIRED_VERSION_REFS; do
  _ASSERTS=$((_ASSERTS+1))
  [ -f "$REFS/$v.md" ] || _fail "required version reference" "$REFS/$v.md exists" "missing"
done
if [ -d "$REFS" ]; then
  out="$(find "$REFS" -maxdepth 1 -type f -name 'ss*.md' | sort | while IFS= read -r f; do check_version_ref "$f"; done)"
  assert_eq 0 "$(errors_of "$out")" "version reference structure: $(printf '%s\n' "$out" | grep '^ERROR')"
  out="$(check_tree "$REFS")"
  printf '%s\n' "$out" | grep '^WARN' >&2
  assert_eq 0 "$(errors_of "$out")" "reference errors: $(printf '%s\n' "$out" | grep '^ERROR')"
  n="$(cat "$REFS"/migrations/*.md 2>/dev/null | grep -cE '^### M[0-9]+-[0-9]{3}' | tr -d ' ')"
  _ASSERTS=$((_ASSERTS+1))
  [ "$n" -gt 0 ] || _fail "map has entries" ">0 entries" "$n"
fi
finish
