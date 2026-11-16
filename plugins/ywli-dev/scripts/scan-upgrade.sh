#!/usr/bin/env bash
# ss-version-aware: scan a SilverStripe project for upgrade items and keep a re-scannable checklist.
# Usage: scan-upgrade.sh --from <a> --to <b> [--dir d] [--checklist path] [--no-exclude]
#        scan-upgrade.sh --patterns <file> [--dir d] [--checklist path] [--no-exclude]   (tests only)
# Env:   SSVA_MIGRATIONS_DIR  override the migrations dir (tests only).
# Patterns file: ID<TAB>grep -E regex<TAB>globs (comma list)<TAB>replacement hint; '#' comments.
# Exit: 0 = no open items in unlocked phases, 1 = open items, 2 = usage/map/regex error.
# Stdout: CHECKLIST=<path>, MANUAL=<unticked manual items>, OPEN=<count> (always the last line).
# Each unlocked phase whose map .md exists also gets "## Ručni pregled (nema grep obrasca) — Faza a→b":
# map entries with no line in the .patterns file. They are ticked by hand ("- [x] ID — ..."), the tick is
# kept across rescans by ID, and they never count toward OPEN or the exit code.
# Skipped dirs (any depth): vendor, node_modules, _resources, resources, .git, lang, .claude,
# silverstripe-cache, .ddev (lang/*.yml i18n keys keep old FQCNs in every major, so they are not upgrade
# items; .claude holds Claude Code worktrees, which would duplicate every hit).
# Item line: "- [ ] ID `file:line` — hint (mapa: ...) — `matched line, trimmed, <= 80 bytes`".
# Field separator inside the script is \037 (unit separator): bash 3.2 uses \001/\177 internally,
# so `IFS=<\001> read` would not split there.
#
# NOTE (deliberate exception to "never modify tracked files"): the checklist is this skill's
# own artifact. If a private project committed it (--no-exclude), re-scans still rewrite it.
# The checklist is REGENERATED on every scan: hand-written prose in it is not preserved, and
# deleting its trailing `<!-- ssva-state -->` block loses the closed ([x]) history (current
# findings are then listed as open). Nothing else in the project is ever written. bash 3.2 / BSD awk compatible.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

usage() {
  echo "usage: scan-upgrade.sh --from <a> --to <b> [--dir d] [--checklist path] [--no-exclude]" >&2
  echo "       scan-upgrade.sh --patterns <file> [--dir d] [--checklist path] [--no-exclude]" >&2
  exit 2
}

FROM=""; TO=""; DIR="$PWD"; CHECKLIST=""; PATFILE=""; DO_EXCLUDE=1
while [ $# -gt 0 ]; do
  case "$1" in
    --from) [ $# -ge 2 ] || usage; FROM="$2"; shift 2 ;;
    --to) [ $# -ge 2 ] || usage; TO="$2"; shift 2 ;;
    --dir) [ $# -ge 2 ] || usage; DIR="$2"; shift 2 ;;
    --checklist) [ $# -ge 2 ] || usage; CHECKLIST="$2"; shift 2 ;;
    --patterns) [ $# -ge 2 ] || usage; PATFILE="$2"; shift 2 ;;
    --no-exclude) DO_EXCLUDE=0; shift ;;
    *) usage ;;
  esac
done

if [ -n "$PATFILE" ]; then
  [ -f "$PATFILE" ] || { echo "scan-upgrade.sh: no such patterns file: $PATFILE" >&2; exit 2; }
else
  case "$FROM$TO" in ''|*[!0-9]*) usage ;; esac
  [ -n "$FROM" ] && [ -n "$TO" ] || usage
  [ "$FROM" -lt "$TO" ] || { echo "scan-upgrade.sh: --from must be < --to" >&2; exit 2; }
fi
[ -d "$DIR" ] || { echo "scan-upgrade.sh: no such directory: $DIR" >&2; exit 2; }
DIR="$(cd "$DIR" && pwd)"

MIGDIR="${SSVA_MIGRATIONS_DIR:-$HERE/../skills/ss-version-aware/references/migrations}"

# checklist path: absolute, or relative to DIR
REL_CL=".claude/ss-upgrade-checklist.md"
if [ -z "$CHECKLIST" ]; then CHECKLIST="$DIR/$REL_CL"
else
  case "$CHECKLIST" in /*) ;; *) CHECKLIST="$DIR/$CHECKLIST" ;; esac
  REL_CL=""
  case "$CHECKLIST" in "$DIR"/*) REL_CL="${CHECKLIST#$DIR/}" ;; esac
fi

# phases: "<n>|<patterns file>|<map name>|<title>"
PHASES=""
if [ -n "$PATFILE" ]; then
  b="$(basename "$PATFILE")"
  PHASES="P|$PATFILE|${b%.patterns}|Faza $b"
  TITLE="SilverStripe upgrade scan ($b) — checklist (ss-version-aware)"
else
  n="$FROM"
  while [ "$n" -lt "$TO" ]; do
    f="$MIGDIR/$n-to-$((n+1)).patterns"
    [ -f "$f" ] || { echo "no migration map for $n→$((n+1))" >&2; exit 2; }
    PHASES="$PHASES$n|$f|$n-to-$((n+1))|Faza $n→$((n+1))
"
    n=$((n+1))
  done
  TITLE="SilverStripe upgrade $FROM → $TO — checklist (ss-version-aware)"
fi

# current major: lock, overridden by what is actually installed
CUR=""
if [ -z "$PATFILE" ]; then
  CUR="$(ssva_major "$(ssva_lock_version "$DIR/composer.lock" silverstripe/framework)")"
  inst="$(ssva_major "$(ssva_installed_version "$DIR/vendor/composer/installed.json" silverstripe/framework)")"
  if [ -n "$inst" ] && [ "$inst" != "$CUR" ]; then CUR="$inst"; fi
  [ -n "$CUR" ] || CUR="$FROM"   # unknown version: assume the project sits at --from
fi

TMPS=""
trap 'rm -f $TMPS' EXIT
newtmp() { local t; t="$(mktemp "${TMPDIR:-/tmp}/ssva-scan.XXXXXX")" || exit 1; TMPS="$TMPS $t"; NEWTMP="$t"; }
newtmp; FOUND="$NEWTMP"; newtmp; OLD="$NEWTMP"; newtmp; MERGED="$NEWTMP"; newtmp; OUT="$NEWTMP"; newtmp; RAW="$NEWTMP"
newtmp; TICKED="$NEWTMP"; newtmp; PIDS="$NEWTMP"
SEP="$(printf '\037')"; newtmp; ERRF="$NEWTMP"
UNLOCKED=" "

# ---- collect findings: phase TAB ID TAB rel TAB line TAB text TAB hint TAB mapname ----
while IFS='|' read -r ph pfile mapname title; do
  [ -n "$ph" ] || continue
  if [ "$ph" != P ] && [ "$CUR" -lt "$ph" ]; then continue; fi
  UNLOCKED="$UNLOCKED$ph "
  # field-exact parse (awk -F'\t'; read would collapse empty fields): 4 fields or exit 2
  newtmp; PARSED="$NEWTMP"
  tr -d '\r' < "$pfile" | awk -F'\t' -v OFS="$SEP" '
    /^[ ]*$/ || /^#/ { next }
    NF != 4 { printf "scan-upgrade.sh: %s line %d: expected 4 tab-separated fields, got %d\n", FILENAME, NR, NF > "/dev/stderr"; bad = 1; next }
    { gsub(/-->/, "--@>", $4); print $1, $2, $3, $4 }
    END { exit bad }' > "$PARSED" 2>"$ERRF"
  if [ $? -ne 0 ]; then
    sed "s|^scan-upgrade.sh: -|scan-upgrade.sh: $pfile|" "$ERRF" >&2; exit 2
  fi
  while IFS="$SEP" read -r id regex globs hint || [ -n "$id" ]; do
    printf '' | grep -E -- "$regex" >/dev/null 2>&1
    if [ $? -eq 2 ]; then echo "scan-upgrade.sh: invalid regex in pattern $id: $regex" >&2; exit 2; fi
    set --
    oldifs="$IFS"; IFS=','
    for g in $globs; do [ -n "$g" ] && set -- "$@" "--include=$g"; done
    IFS="$oldifs"
    # --null: "path<NUL>line:text"; NUL mapped to \037 so colons in file names are safe
    (cd "$DIR" && grep -rnE -I --null --exclude-dir=vendor --exclude-dir=node_modules --exclude-dir=_resources \
      --exclude-dir=resources --exclude-dir=.git --exclude-dir=lang --exclude-dir=.claude \
      --exclude-dir=silverstripe-cache --exclude-dir=.ddev "$@" -- "$regex" . 2>/dev/null) | tr '\000' '\037' > "$RAW"
    # id/hint/map/skip go through ENVIRON: awk -v would interpret backslash escapes
    SSVA_PH="$ph" SSVA_ID="$id" SSVA_HINT="$hint" SSVA_MAP="$mapname" SSVA_SKIP="$REL_CL" awk -F'\037' '
      BEGIN { ph = ENVIRON["SSVA_PH"]; id = ENVIRON["SSVA_ID"]; hint = ENVIRON["SSVA_HINT"]; map = ENVIRON["SSVA_MAP"]; skip = ENVIRON["SSVA_SKIP"] }
      {
        if (NF < 2) next
        rel = $1; sub(/^\.\//, "", rel)
        rest = $2; for (k = 3; k <= NF; k++) rest = rest "\037" $k
        sub(/\r$/, "", rest)
        j = index(rest, ":"); if (j == 0) next
        ln = substr(rest, 1, j - 1); text = substr(rest, j + 1)
        if (rel == skip) next
        gsub(/\t/, " ", text); gsub(/-->/, "--@>", text)
        sub(/^ +/, "", text); sub(/ +$/, "", text)
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", ph, id, rel, ln, text, hint, map
      }' "$RAW" >> "$FOUND"
  done < "$PARSED"
done <<EOF
$PHASES
EOF

# ---- previous state (hidden block at the end of the checklist) ----
# record: phase TAB ID TAB rel TAB ord TAB line TAB hint TAB map TAB text
if [ -f "$CHECKLIST" ]; then
  ssva_strip_cr "$CHECKLIST" | awk '
    $0 == "<!-- ssva-state" { s = 1; next }
    s && $0 == "-->" { s = 0; next }
    s { print }' > "$OLD"
  # manual-review items ticked by hand: "- [x] <ID> — ..." (pattern items have a backtick after the ID)
  ssva_strip_cr "$CHECKLIST" | sed -n -E 's/^- \[[xX]\] (M[0-9]{2}-[0-9]{3}) — .*/\1/p' > "$TICKED"
fi

# manual_section <patterns file> <title>: map entries (### M..-NNN in the same-named .md) without a pattern
# line, as "- [ ] ID — summary (mapa: ...)". Ticks come from $TICKED. File names go through ENVIRON.
manual_section() {
  local md="${1%.patterns}.md" mapname
  [ -f "$md" ] || return 0
  mapname="$(basename "${1%.patterns}")"
  tr -d '\r' < "$1" | awk -F'\t' '/^[ ]*$/ || /^#/ { next } { print $1 }' > "$PIDS"
  tr -d '\r' < "$md" | SSVA_PIDS="$PIDS" SSVA_TICKED="$TICKED" SSVA_MAP="$mapname" SSVA_TITLE="$2" awk '
    BEGIN {
      while ((getline l < ENVIRON["SSVA_PIDS"]) > 0) has[l] = 1
      while ((getline l < ENVIRON["SSVA_TICKED"]) > 0) tick[l] = 1
      map = ENVIRON["SSVA_MAP"]
    }
    function flush() {
      if (id == "" || (id in has)) { id = ""; return }
      if (sum == "") sum = "(vidi mapu)"
      gsub(/-->/, "--@>", sum)
      line[++n] = sprintf("- [%s] %s — %s (mapa: references/migrations/%s.md#%s)", ((id in tick) ? "x" : " "), id, sum, map, tolower(id))
      id = ""
    }
    /^#/ {
      flush()
      if ($0 ~ /^### M[0-9][0-9]-[0-9][0-9][0-9][ ]*$/) { id = $2; sum = "" }
      next
    }
    id != "" && sum == "" && index($0, "**Staro:**") == 1 {
      sum = $0
      sub(/[ ]*·[ ]*\*\*Vrsta:\*\*.*$/, "", sum)
      gsub(/\*\*/, "", sum)
      sub(/^[ \t]+/, "", sum); sub(/[ \t]+$/, "", sum)
    }
    END {
      flush()
      if (n == 0) exit
      printf "\n## Ručni pregled (nema grep obrasca) — %s\n", ENVIRON["SSVA_TITLE"]
      for (i = 1; i <= n; i++) print line[i]
    }'
}

# ---- merge: status TAB record ----
SSVA_OLD="$OLD" awk -F'\t' -v OFS='\t' -v unl="$UNLOCKED" '
  FILENAME == ENVIRON["SSVA_OLD"] {                            # old state (may be empty: do not use FNR==NR)
    no++
    op[no] = $1; oi[no] = $2; orl[no] = $3; oo[no] = $4; ol[no] = $5; oh[no] = $6; om[no] = $7; ot[no] = $8
    next
  }
  {                                             # found
    nf++
    k = $1 SUBSEP $2 SUBSEP $3 SUBSEP $5
    ord = ++cnt[k]
    fk = k SUBSEP ord
    fline[fk] = $4; fhint[fk] = $6; fmap[fk] = $7
    fo[nf] = fk; fph[nf] = $1; fid[nf] = $2; frel[nf] = $3; ford[nf] = ord; ftext[nf] = $5
  }
  END {
    for (i = 1; i <= no; i++) {
      if (index(unl, " " op[i] " ") == 0) continue
      fk = op[i] SUBSEP oi[i] SUBSEP orl[i] SUBSEP ot[i] SUBSEP oo[i]
      used[fk] = 1
      if (fk in fline) print "o", op[i], oi[i], orl[i], oo[i], fline[fk], fhint[fk], fmap[fk], ot[i]
      else print "x", op[i], oi[i], orl[i], oo[i], ol[i], oh[i], om[i], ot[i]
    }
    for (i = 1; i <= nf; i++) {
      fk = fo[i]
      if (fk in used) continue
      print "o", fph[i], fid[i], frel[i], ford[i], fline[fk], fhint[fk], fmap[fk], ftext[i]
    }
  }' "$OLD" "$FOUND" > "$MERGED"

# ---- render ----
{
  printf '# %s\n' "$TITLE"
  while IFS='|' read -r ph pfile mapname title; do
    [ -n "$ph" ] || continue
    printf '\n## %s' "$title"
    if [ "$ph" != P ] && [ "$CUR" -lt "$ph" ]; then
      printf ' (zaključano dok lock ne pokaže %s.x)\n' "$ph"
      continue
    fi
    printf '\n'
    # byte semantics (LC_ALL=C) for the 80-byte cut; a cut multibyte char is dropped whole
    SSVA_PH="$ph" LC_ALL=C awk -F'\t' '
      BEGIN { ph = ENVIRON["SSVA_PH"] }
      function code(t,   s, run, best, f, i, c) {
        if (length(t) > 80) {
          t = substr(t, 1, 77)
          while (t != "" && (c = substr(t, length(t), 1)) >= "\200" && c <= "\277") t = substr(t, 1, length(t) - 1)
          if (t != "" && substr(t, length(t), 1) >= "\300") t = substr(t, 1, length(t) - 1)
          t = t "..."
        }
        # inline code: fence one backtick longer than the longest backtick run, padded if needed
        best = 0; s = t
        while (match(s, /`+/)) { if (RLENGTH > best) best = RLENGTH; s = substr(s, RSTART + RLENGTH) }
        f = "`"; for (i = 0; i < best; i++) f = f "`"
        if (best > 0) return f " " t " " f
        return f t f
      }
      $2 == ph {
        printf "- [%s] %s `%s:%s` — %s (mapa: references/migrations/%s.md#%s) — %s\n", ($1 == "x" ? "x" : " "), $3, $4, $6, $7, $8, tolower($3), code($9)
      }' "$MERGED"
    manual_section "$pfile" "$title"
  done <<EOF
$PHASES
EOF
  printf '\n<!-- ssva-state\n'
  cat "$MERGED" | cut -f2-
  printf -- '-->\n'
} > "$OUT"

mkdir -p "$(dirname "$CHECKLIST")" || exit 2
cat "$OUT" > "$CHECKLIST" || exit 2
if [ "$DO_EXCLUDE" = 1 ] && [ -n "$REL_CL" ]; then ssva_add_exclude "$DIR" "$REL_CL"; fi

OPEN="$(grep -c '^o' "$MERGED" | tr -d ' ')"
MANUAL="$(grep -cE '^- \[ \] M[0-9]{2}-[0-9]{3} — ' "$OUT" | tr -d ' ')"
echo "CHECKLIST=$CHECKLIST"
echo "MANUAL=$MANUAL"
echo "OPEN=$OPEN"
[ "$OPEN" = 0 ]
