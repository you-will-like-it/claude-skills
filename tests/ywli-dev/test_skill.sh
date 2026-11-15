#!/usr/bin/env bash
# Structural test for skills/ss-version-aware/SKILL.md and tests/evals.md.
# Checks: frontmatter (name, description <= 1024 bytes, no angle brackets), body size, every
# ${CLAUDE_PLUGIN_ROOT}/... and references/... path exists, block.sh subcommands and scan-upgrade.sh
# flags named in SKILL.md exist, required topics are covered, evals.md has the 9 scenarios with all
# fields and existing fixtures, and `claude plugin validate` passes (skipped if the CLI is unusable).
# The checkers first run on broken mutants (must catch every planted error), then on the real files.
# bash 3.2 / BSD compatible.
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
PLUGIN="$ROOT/plugins/ywli-dev"
SKILL_DIR="$PLUGIN/skills/ss-version-aware"
SKILL="$SKILL_DIR/SKILL.md"
EVALS="$HERE/evals.md"
MAX_SKILL_LINES=200
MAX_DESC_BYTES=1024
EVAL_IDS="E1a E1b E2 E3 E4 E5 E6 E7 E8"
# Topics SKILL.md must name (fixed strings).
REQUIRED='detect.sh
block.sh init
block.sh refresh
block.sh ack
scan-upgrade.sh --from 5 --to 6
OPEN=0
OPEN>0
MANUAL=
Ručni pregled (nema grep obrasca)
BEFORE your first `scan-upgrade.sh` call
⚠
vendor/
grep -rn
framework/ cms/
references/ss3.md
references/ss4.md
references/ss5.md
references/ss6.md
references/migrations/4-to-5.md
references/migrations/5-to-6.md
## Rector
TARGET
postavi ss-version-aware
or`/`and
--no-exclude
NOTE=agents-md-imported
Režim projekta je promijenjen
composer.json
Upgrade checklista
offer the upgrade workflow (§7)'

errors_of() { printf '%s\n' "$1" | grep -c '^ERROR' | tr -d ' '; }

# frontmatter_field <file> <key>: value of a top-level key in the leading --- block
# (folded continuation lines joined with a space; surrounding quotes removed).
frontmatter_field() {
  tr -d '\r' < "$1" | awk -v k="$2" -v q="'" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    grab && /^[ \t]+/ { sub(/^[ \t]+/, ""); v = v (v == "" ? "" : " ") $0; next }
    { grab = 0 }
    index($0, k ":") == 1 { v = substr($0, length(k) + 2); sub(/^[ \t]+/, "", v); if (v == ">" || v == "|" || v == ">-" || v == "|-") v = ""; grab = 1 }
    END {
      a = substr(v, 1, 1); z = substr(v, length(v), 1)
      if (length(v) >= 2 && a == z && (a == "\"" || a == q)) v = substr(v, 2, length(v) - 2)
      printf "%s", v
    }'
}

# path_tokens <file> <prefix-regex>: tokens starting with the prefix, cut at whitespace, backtick,
# quote or ")", trailing . , : ; stripped. Tokens holding "<" (placeholders) are printed with a "SKIP " prefix.
path_tokens() {
  tr -d '\r' < "$1" | grep -oE -- "$2[^[:space:]\`'\")]*" | sed -E 's/[.,:;]+$//' | sort -u |
    while IFS= read -r t; do case "$t" in *"<"*) echo "SKIP $t" ;; *) echo "$t" ;; esac; done
}

# check_skill <SKILL.md> <plugin root>: one ERROR line per problem.
check_skill() {
  local f="$1" plug="$2" sdir name desc raw norm n t rel sub flag
  sdir="$(dirname "$f")"
  [ -f "$f" ] || { echo "ERROR $f: missing"; return; }
  [ "$(head -n 1 "$f" | tr -d '\r')" = "---" ] || echo "ERROR $f: no frontmatter (first line must be ---)"
  [ "$(tr -d '\r' < "$f" | grep -c '^---$' | tr -d ' ')" -ge 2 ] || echo "ERROR $f: frontmatter not closed"
  name="$(frontmatter_field "$f" name)"
  [ "$name" = "$(basename "$sdir")" ] || echo "ERROR $f: name '$name' does not match directory '$(basename "$sdir")'"
  printf '%s' "$name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || echo "ERROR $f: name '$name' is not lowercase-hyphen"
  desc="$(frontmatter_field "$f" description)"
  [ -n "$desc" ] || echo "ERROR $f: empty description"
  n="$(printf '%s' "$desc" | LC_ALL=C wc -c | tr -d ' ')"
  [ "$n" -le "$MAX_DESC_BYTES" ] || echo "ERROR $f: description is $n bytes (max $MAX_DESC_BYTES)"
  case "$desc" in *"<"*|*">"*) echo "ERROR $f: description contains angle brackets" ;; esac
  raw="$(tr -d '\r' < "$f" | sed -n 's/^description:[ ]*//p' | head -n 1)"
  case "$raw" in
    \"*|\'*|'>'*|'|'*) ;;
    *": "*|*" #"*) echo "ERROR $f: unquoted description contains ': ' or ' #' (invalid YAML plain scalar)" ;;
  esac
  n="$(wc -l < "$f" | tr -d ' ')"
  [ "$n" -le "$MAX_SKILL_LINES" ] || echo "ERROR $f: $n lines (max $MAX_SKILL_LINES)"
  path_tokens "$f" '\$\{CLAUDE_PLUGIN_ROOT\}/' | while IFS= read -r t; do
    case "$t" in SKIP*) continue ;; esac
    rel="${t#\$\{CLAUDE_PLUGIN_ROOT\}/}"
    [ -e "$plug/$rel" ] || echo "ERROR $f: path does not exist: $t"
  done
  path_tokens "$f" 'references/' | while IFS= read -r t; do
    case "$t" in SKIP*) continue ;; esac
    [ -e "$sdir/$t" ] || echo "ERROR $f: reference does not exist: $t"
  done
  # quotes removed, so `"${CLAUDE_PLUGIN_ROOT}/scripts/block.sh" refresh` reads as `block.sh refresh`
  norm="$(tr -d '\r"' < "$f")"
  printf '%s\n' "$norm" | grep -oE 'block\.sh [a-z]+' | sort -u | while read -r _ sub; do
    case "$sub" in init|refresh|show|ack) ;; *) echo "ERROR $f: unknown block.sh subcommand: $sub" ;; esac
  done
  printf '%s\n' "$norm" | grep -oE 'scan-upgrade\.sh( --[a-z-]+( [^ `-][^ `]*)?)+' | grep -oE -- '--[a-z-]+' | sort -u | while read -r flag; do
    grep -qE -- "^[[:space:]]*$flag\)" "$plug/scripts/scan-upgrade.sh" 2>/dev/null || echo "ERROR $f: unknown scan-upgrade.sh flag: $flag"
  done
  # grep examples must be BSD-safe: \b is a GNU extension (use -w or an explicit class)
  printf '%s\n' "$norm" | grep -n 'grep' | grep -F '\b' | while IFS= read -r t; do
    echo "ERROR $f: GNU-only \\b in grep example (line ${t%%:*})"
  done
  printf '%s\n' "$REQUIRED" | while IFS= read -r t; do
    [ -n "$t" ] || continue
    printf '%s\n' "$norm" | grep -qF -- "$t" || echo "ERROR $f: does not mention: $t"
  done
}

# check_evals <evals.md> <fixtures root>: scenarios, fields, fixtures.
check_evals() {
  local f="$1" fx="$2" id sec fixture
  [ -f "$f" ] || { echo "ERROR $f: missing"; return; }
  for id in $EVAL_IDS; do
    n="$(tr -d '\r' < "$f" | grep -cE "^## $id: ." | tr -d ' ')"
    [ "$n" = 1 ] || { echo "ERROR $f: expected one '## $id: <title>' heading, found $n"; continue; }
    sec="$(tr -d '\r' < "$f" | awk -v id="$id" '/^## / { on = (index($0, "## " id ": ") == 1) } on')"
    for fld in '**Fixture:**' '**Setup:**' '**Prompt:**' '**Pass criteria:**'; do
      printf '%s\n' "$sec" | grep -qF -- "$fld" || echo "ERROR $f: $id has no $fld"
    done
    printf '%s\n' "$sec" | grep -qE '^[[:space:]]*- \[ \] ' || echo "ERROR $f: $id has no '- [ ]' pass criteria"
    fixture="$(printf '%s\n' "$sec" | grep -F -- '**Fixture:**' | head -n 1 | grep -oE 'tests/fixtures/[A-Za-z0-9._-]+' | head -n 1)"
    if [ -z "$fixture" ]; then echo "ERROR $f: $id fixture is not a tests/fixtures/<name> path"
    elif [ ! -d "$fx/${fixture#tests/fixtures/}" ]; then echo "ERROR $f: $id fixture does not exist: $fixture"
    fi
  done
  n="$(tr -d '\r' < "$f" | grep -cE '^## E[0-9]' | tr -d ' ')"
  [ "$n" = "$(echo $EVAL_IDS | wc -w | tr -d ' ')" ] || echo "ERROR $f: expected $(echo $EVAL_IDS | wc -w | tr -d ' ') scenarios, found $n"
}

# --- self-test on broken mutants ---
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ssskill.XXXXXX")"
mkdir -p "$TMP/p/scripts" "$TMP/p/skills/demo/references/migrations" "$TMP/fx/ok"
printf '#!/usr/bin/env bash\ncase "$1" in\n    --from) ;;\n    --to) ;;\nesac\n' > "$TMP/p/scripts/scan-upgrade.sh"
: > "$TMP/p/scripts/detect.sh"
: > "$TMP/p/skills/demo/references/ss6.md"
long_desc="$(i=0; while [ $i -lt 110 ]; do printf 'abcdefghij'; i=$((i+1)); done)"
cat > "$TMP/p/skills/demo/SKILL.md" <<EOF
---
name: wrong-name
description: $long_desc <tag>
---
Run \`bash "\${CLAUDE_PLUGIN_ROOT}/scripts/detect.sh"\` and \`\${CLAUDE_PLUGIN_ROOT}/scripts/missing.sh\`.
Read references/ss6.md, references/ss9.md and references/ss<MAJOR>.md.
Then block.sh init, \`bash "x/block.sh" frobnicate\`; \`bash "x/scan-upgrade.sh" --from 5 --to 6 --bogus x\`.
   grep -rn "class Foo\\b" vendor/
EOF
out="$(check_skill "$TMP/p/skills/demo/SKILL.md" "$TMP/p")"
assert_contains "$out" "name 'wrong-name' does not match directory 'demo'" "self-test: name/dir"
assert_contains "$out" "description is 1106 bytes" "self-test: description length"
assert_contains "$out" "description contains angle brackets" "self-test: angle brackets"
assert_contains "$out" "path does not exist: \${CLAUDE_PLUGIN_ROOT}/scripts/missing.sh" "self-test: plugin path"
assert_not_contains "$out" "scripts/detect.sh" "self-test: existing plugin path ok (quote stripped)"
assert_contains "$out" "reference does not exist: references/ss9.md" "self-test: reference path"
assert_not_contains "$out" "references/ss6.md" "self-test: existing reference ok (period stripped)"
assert_not_contains "$out" "ss<MAJOR>" "self-test: placeholder skipped"
assert_contains "$out" "unknown block.sh subcommand: frobnicate" "self-test: block.sh subcommand"
assert_contains "$out" "unknown scan-upgrade.sh flag: --bogus" "self-test: scan flag"
assert_not_contains "$out" "flag: --from" "self-test: known flag ok"
assert_contains "$out" "does not mention: block.sh ack" "self-test: required topic"
assert_contains "$out" "GNU-only \\b in grep example (line 8)" "self-test: \\b in grep"
printf -- '---\nname: demo\ndescription: "ok"\n---\nbody\n' > "$TMP/p/skills/demo/SKILL.md"
out="$(check_skill "$TMP/p/skills/demo/SKILL.md" "$TMP/p")"
assert_not_contains "$out" "name '" "self-test: matching name ok"
assert_not_contains "$out" "description" "self-test: quoted short description ok"
printf -- '---\nname: demo\ndescription: Does x. Triggers: y\n---\nbody\n' > "$TMP/p/skills/demo/SKILL.md"
assert_contains "$(check_skill "$TMP/p/skills/demo/SKILL.md" "$TMP/p")" "invalid YAML plain scalar" "self-test: ': ' in plain description"
printf -- '---\nname: demo\ndescription: "Does x. Triggers: y"\n---\nbody\n' > "$TMP/p/skills/demo/SKILL.md"
assert_not_contains "$(check_skill "$TMP/p/skills/demo/SKILL.md" "$TMP/p")" "plain scalar" "self-test: quoted description may hold ': '"
printf -- '---\nname: demo\ndescription: >\n  folded\n  text\n---\nbody\n' > "$TMP/fold.md"
assert_eq "folded text" "$(frontmatter_field "$TMP/fold.md" description)" "self-test: folded description"
printf 'no frontmatter\n' > "$TMP/p/skills/demo/SKILL.md"
assert_contains "$(check_skill "$TMP/p/skills/demo/SKILL.md" "$TMP/p")" "no frontmatter" "self-test: frontmatter required"
{ printf -- '---\nname: demo\ndescription: x\n---\n'; i=0; while [ $i -lt 201 ]; do echo l; i=$((i+1)); done; } > "$TMP/p/skills/demo/SKILL.md"
assert_contains "$(check_skill "$TMP/p/skills/demo/SKILL.md" "$TMP/p")" "lines (max 200)" "self-test: line cap"

cat > "$TMP/evals.md" <<'EOF'
# Evals
## E1a: ok
**Fixture:** `tests/fixtures/ok`
**Setup:** none
**Prompt:** x
**Pass criteria:**
- [ ] y
## E1b: missing fixture dir
**Fixture:** `tests/fixtures/nope`
**Setup:** none
**Prompt:** x
**Pass criteria:**
- [ ] y
## E2: no criteria list
**Fixture:** `tests/fixtures/ok`
**Setup:** none
**Prompt:** x
**Pass criteria:** none
## E3: no prompt
**Fixture:** `tests/fixtures/ok`
**Setup:** none
**Pass criteria:**
- [ ] y
## E3: duplicate
EOF
out="$(check_evals "$TMP/evals.md" "$TMP/fx")"
assert_not_contains "$out" "E1a" "self-test evals: complete scenario ok"
assert_contains "$out" "E1b fixture does not exist: tests/fixtures/nope" "self-test evals: fixture dir"
assert_contains "$out" "E2 has no '- [ ]' pass criteria" "self-test evals: criteria checklist"
assert_contains "$out" "expected one '## E3: <title>' heading, found 2" "self-test evals: duplicate id"
assert_contains "$out" "expected one '## E4: <title>' heading, found 0" "self-test evals: missing id"
assert_contains "$out" "expected 9 scenarios, found 5" "self-test evals: scenario count"
sed -i.bak '/^## E3: duplicate$/d' "$TMP/evals.md"
assert_contains "$(check_evals "$TMP/evals.md" "$TMP/fx")" "E3 has no **Prompt:**" "self-test evals: missing field"

# --- the real files ---
out="$(check_skill "$SKILL" "$PLUGIN")"
assert_eq 0 "$(errors_of "$out")" "SKILL.md: $(printf '%s\n' "$out" | grep '^ERROR')"
out="$(check_evals "$EVALS" "$HERE/fixtures")"
assert_eq 0 "$(errors_of "$out")" "evals.md: $(printf '%s\n' "$out" | grep '^ERROR')"

# --- claude plugin validate (offline); skipped when the CLI is absent or unusable ---
if [ "${SSVA_SKIP_PLUGIN_VALIDATE:-0}" = 1 ]; then
  echo "SKIP: claude plugin validate (SSVA_SKIP_PLUGIN_VALIDATE=1)" >&2
elif command -v claude >/dev/null 2>&1 && claude plugin validate --help >/dev/null 2>&1; then
  vout="$(claude plugin validate "$PLUGIN" 2>&1)"; vrc=$?
  assert_eq 0 "$vrc" "claude plugin validate exit: $vout"
  assert_contains "$vout" "Validation passed" "claude plugin validate verdict"
else
  echo "SKIP: claude plugin validate (claude CLI not available)" >&2
fi
finish
