#!/usr/bin/env bash
# ss-version-aware: render the version block and write it to CLAUDE.md / CLAUDE.local.md.
# Usage: block.sh init|refresh|show|ack [dir]
# bash 3.2 compatible; no php/jq/python; never edits tracked files.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

START='<!-- ss-version-aware:start -->'
END='<!-- ss-version-aware:end -->'
CR="$(printf '\r')"

usage() { echo "usage: block.sh init|refresh|show|ack [dir]" >&2; exit 64; }

CMD="${1:-}"
case "$CMD" in init|refresh|show|ack) ;; *) usage ;; esac
DIR="${2:-$PWD}"
[ -d "$DIR" ] || { echo "block.sh: no such directory: $DIR" >&2; exit 2; }
DIR="$(cd "$DIR" && pwd)"

# newtmp sets NEWTMP (never call it inside $(...): the subshell would lose the TMPS entry and leak).
# Each path is stored on its own line so the cleanup survives spaces in TMPDIR.
TMPS=""
cleanup() {
  local t
  while IFS= read -r t; do [ -z "$t" ] || rm -f "$t" "$t.2"; done <<EOF
$TMPS
EOF
}
trap cleanup EXIT
newtmp() {
  local t; t="$(mktemp "${TMPDIR:-/tmp}/ssva-block.XXXXXX")" || exit 1
  TMPS="$TMPS
$t"; NEWTMP="$t"
}

# ---- detection (parsed line by line; never eval/source) ----
SS_PROJECT=none; SS_VERSION=""; SS_MAJOR=""; SS_MODE=normal; SS_TARGET_MAJOR=""
SS_COMPAT_MAJORS=""; SS_MODULES=""; PHP_VERSION=""; BUILD_TOOL=none; DDEV=0; LOCK_HASH=nolock
detect() {
  local out line k v
  out="$(bash "$SCRIPT_DIR/detect.sh" "$DIR" 2>/dev/null)"
  while IFS= read -r line; do
    line="${line%$CR}"
    k="${line%%=*}"; v="${line#*=}"
    case "$k" in
      SS_PROJECT) SS_PROJECT="$v" ;;
      SS_VERSION) SS_VERSION="$v" ;;
      SS_MAJOR) SS_MAJOR="$v" ;;
      SS_MODE) SS_MODE="$v" ;;
      SS_TARGET_MAJOR) SS_TARGET_MAJOR="$v" ;;
      SS_COMPAT_MAJORS) SS_COMPAT_MAJORS="$v" ;;
      SS_MODULES) SS_MODULES="$v" ;;
      PHP_VERSION) PHP_VERSION="$v" ;;
      BUILD_TOOL) BUILD_TOOL="$v" ;;
      DDEV) DDEV="$v" ;;
      LOCK_HASH) LOCK_HASH="$v" ;;
    esac
  done <<EOF
$out
EOF
}

# ---- git helpers ----
IN_GIT=0
git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 && IN_GIT=1

is_tracked() { # name
  [ "$IN_GIT" = 1 ] || return 1
  git -C "$DIR" ls-files --error-unmatch -- "$1" >/dev/null 2>&1
}

# has_block <file>: both markers present, start before end.
has_block() {
  [ -f "$1" ] || return 1
  tr -d '\r' < "$1" | awk -v s="$START" -v e="$END" '
    $0 == s { st = 1; next }
    st && $0 == e { ok = 1; exit }
    END { exit ok ? 0 : 1 }'
}

# usable <name>: untracked file that holds a block.
usable() { ! is_tracked "$1" && has_block "$DIR/$1"; }

find_block_file() { # echoes name or nothing
  if usable CLAUDE.md; then echo CLAUDE.md
  elif usable CLAUDE.local.md; then echo CLAUDE.local.md
  fi
}

# ---- rendering ----
compat_list() { # "5 6" -> "SS5 i SS6"
  local out="" total m i=0
  total="$(printf '%s\n' "$1" | wc -w | tr -d ' ')"
  for m in $1; do
    i=$((i+1))
    if [ "$i" -eq 1 ]; then out="SS$m"
    elif [ "$i" -eq "$total" ]; then out="$out i SS$m"
    else out="$out, SS$m"; fi
  done
  echo "$out"
}

# checklist_line: "Upgrade checklista: N otvorenih stavki (+M za ručni pregled) — <path>" while the
# scanner's checklist has unticked items (N: pattern items, M: "Ručni pregled" items); else nothing.
CHECKLIST_REL=".claude/ss-upgrade-checklist.md"
checklist_line() {
  local f="$DIR/$CHECKLIST_REL" counts
  [ -f "$f" ] || return 0
  counts="$(tr -d '\r' < "$f" | awk '
    $0 == "<!-- ssva-state" { exit }
    /^## / { man = (index($0, "## Ručni pregled") == 1); next }
    /^- \[ \] / { if (man) m++; else n++ }
    END { print n + 0, m + 0 }')"
  set -- $counts
  [ "$1" = 0 ] && [ "$2" = 0 ] && return 0
  echo "Upgrade checklista: $1 otvorenih stavki (+$2 za ručni pregled) — $CHECKLIST_REL"
}

# render <warn-line-or-empty>: block (LF) on stdout.
render() {
  local hdr modules
  hdr="SilverStripe $SS_VERSION (major $SS_MAJOR) — režim: $SS_MODE"
  [ "$SS_MODE" = upgrade ] && [ -n "$SS_TARGET_MAJOR" ] && hdr="$hdr → $SS_TARGET_MAJOR"
  [ "$SS_MODE" = compat ] && [ -n "$SS_COMPAT_MAJORS" ] && hdr="$hdr, kompatibilno: $SS_COMPAT_MAJORS"
  echo "$START"
  echo "## SilverStripe (ss-version-aware)"
  echo "$hdr"
  if [ -n "$SS_MODULES" ]; then
    modules="$(printf '%s' "$SS_MODULES" | sed 's/,/, /g')"
    echo "Moduli: $modules"
  fi
  if [ "$DDEV" = 1 ]; then
    if [ -n "$PHP_VERSION" ]; then echo "PHP $PHP_VERSION (DDEV)"; else echo "DDEV"; fi
  elif [ -n "$PHP_VERSION" ]; then
    echo "PHP $PHP_VERSION"
  fi
  echo "Build: $BUILD_TOOL"
  echo "Prije upotrebe bilo kojeg SilverStripe API-ja koristi skill ss-version-aware (referenca za ovu verziju); ako stavka nije u referenci, provjeri u vendor/."
  if [ "$SS_MODE" = upgrade ] && [ -n "$SS_TARGET_MAJOR" ]; then
    echo "Novi kod piši isključivo za SS$SS_TARGET_MAJOR; postojeći mijenjaj prema mapi migracije i .claude/ss-upgrade-checklist.md."
  elif [ "$SS_MODE" = compat ] && [ -n "$SS_COMPAT_MAJORS" ]; then
    echo "Koristi samo API koji postoji u $(compat_list "$SS_COMPAT_MAJORS"), ili verzijski uslovljen kod."
  fi
  checklist_line
  [ -z "$1" ] || echo "$1"
  echo "lock: $LOCK_HASH"
  echo "$END"
}

# extract_block <file>: first complete block (CR stripped), markers included.
extract_block() {
  tr -d '\r' < "$1" | awk -v s="$START" -v e="$END" '
    $0 == s { st = 1; n = 0 }
    st { buf[++n] = $0 }
    st && $0 == e { for (i = 1; i <= n; i++) print buf[i]; exit }'
}

WARN_PREFIX="⚠ Verzija promijenjena"
strip_warn() { grep -v "^$WARN_PREFIX" || true; }

# ---- writing ----
file_has_cr() { # first line ends with CR
  [ -s "$1" ] || return 1
  head -n 1 "$1" | tr -d '\n' | grep -q "$CR\$"
}

# write_block <name> <blockfile>: replace in place or append. Text outside markers is preserved.
write_block() {
  local f="$DIR/$1" blk="$2" cr=0 tmp eol line nonl=0 size lastend=0
  if is_tracked "$1"; then
    echo "block.sh: $1 is tracked; refusing to write" >&2
    exit 3
  fi
  file_has_cr "$f" && cr=1
  [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ] && nonl=1
  if has_block "$f"; then
    newtmp; tmp="$NEWTMP"
    awk -v s="$START" -v e="$END" -v cr="$cr" '
      FNR == NR { b[++nb] = $0; next }
      {
        line = $0; sub(/\r$/, "", line)
        if (done) { print; next }
        if (line == s) {
          if (inb) { for (i = 1; i <= n; i++) print buf[i] }
          inb = 1; n = 0; buf[++n] = $0; next
        }
        if (inb) {
          buf[++n] = $0
          if (line == e) {
            for (i = 1; i <= nb; i++) { if (cr) printf "%s\r\n", b[i]; else print b[i] }
            inb = 0; done = 1
          }
          next
        }
        print
      }
      END { if (inb) for (i = 1; i <= n; i++) print buf[i] }
    ' "$blk" "$f" > "$tmp" || return 1
    if [ "$nonl" = 1 ]; then
      # original had no final newline: keep it that way (drop the one awk added)
      [ "$(tail -n 1 "$f" | tr -d '\r')" = "$END" ] && lastend=1
      size="$(wc -c < "$tmp" | tr -d ' ')"
      if [ "$lastend" = 1 ] && [ "$cr" = 1 ]; then size=$((size-2)); else size=$((size-1)); fi
      head -c "$size" "$tmp" > "$tmp.2" && mv "$tmp.2" "$tmp"
    fi
    cat "$tmp" > "$f"
  else
    eol="
"
    [ "$cr" = 1 ] && eol="$CR
"
    if [ -s "$f" ]; then
      [ -z "$(tail -c 1 "$f")" ] || printf '%s' "$eol" >> "$f"
      printf '%s' "$eol" >> "$f"
    fi
    while IFS= read -r line; do
      printf '%s%s' "$line" "$eol" >> "$f"
    done < "$blk"
  fi
}

add_exclude() { ssva_add_exclude "$DIR" "$1"; } # shared impl lives in lib.sh

parse_header() { # block text on stdin -> "major mode"
  grep -m 1 '(major ' | sed -E 's/.*\(major ([^)]*)\)[^:]*: ([a-z]+).*/\1 \2/'
}

# ---- commands ----
case "$CMD" in
  show)
    detect
    [ "$SS_PROJECT" != none ] || { echo "block.sh: not a SilverStripe project: $DIR" >&2; exit 2; }
    render ""
    ;;

  init)
    detect
    [ "$SS_PROJECT" != none ] || { echo "block.sh: not a SilverStripe project: $DIR" >&2; exit 2; }
    target="$(find_block_file)"
    if [ -z "$target" ]; then
      if is_tracked CLAUDE.md; then target=CLAUDE.local.md; else target=CLAUDE.md; fi
    fi
    if is_tracked "$target"; then
      echo "block.sh: $target is tracked; refusing to write" >&2
      exit 3
    fi
    newtmp; b="$NEWTMP"; render "" > "$b"
    agents=""
    if [ ! -e "$DIR/$target" ] && [ ! -e "$DIR/CLAUDE.md" ] && [ ! -e "$DIR/.claude/CLAUDE.md" ] \
       && [ ! -e "$DIR/CLAUDE.local.md" ]; then
      # Creating the first CLAUDE.md would make Claude Code stop reading AGENTS.md: import it.
      for a in AGENTS.md .claude/AGENTS.md; do
        [ -f "$DIR/$a" ] && agents="$agents@$a
"
      done
    fi
    if [ -n "$agents" ]; then
      newtmp; printf '%s\n' "$agents" > "$NEWTMP"; cat "$b" >> "$NEWTMP"; cat "$NEWTMP" > "$DIR/$target"
    else
      write_block "$target" "$b"
    fi
    add_exclude "$target"
    echo "TARGET=$target"
    [ "$IN_GIT" = 1 ] || echo "NOTE=no-git"
    [ -z "$agents" ] || echo "NOTE=agents-md-imported"
    ;;

  ack|refresh)
    target="$(find_block_file)"
    [ -n "$target" ] || exit 0
    detect
    [ "$SS_PROJECT" != none ] || exit 0
    f="$DIR/$target"
    old="$(extract_block "$f")"
    if [ "$CMD" = ack ]; then
      newtmp; b="$NEWTMP"; render "" > "$b"
      write_block "$target" "$b"
      exit 0
    fi
    oldbase="$(printf '%s\n' "$old" | strip_warn)"
    newbase="$(render "")"
    oldwarn="$(printf '%s\n' "$old" | grep "^$WARN_PREFIX" | head -n 1)"
    read -r oldmajor oldmode <<EOF
$(printf '%s\n' "$old" | parse_header)
EOF
    changed=0; [ "$oldbase" = "$newbase" ] || changed=1
    warn="$oldwarn"
    echo_major=""; echo_mode=""
    if [ -n "$oldmajor" ] && [ "$oldmajor" != "$SS_MAJOR" ]; then
      warn="$WARN_PREFIX ($oldmajor → $SS_MAJOR) — pokreni ss-version-aware."
      echo_major="MAJOR_CHANGED=$oldmajor->$SS_MAJOR"
    fi
    if [ -n "$oldmode" ] && [ "$oldmode" != "$SS_MODE" ]; then
      [ -n "$echo_major" ] || warn="$WARN_PREFIX ($oldmode → $SS_MODE) — pokreni ss-version-aware."
      echo_mode="MODE_CHANGED=$oldmode->$SS_MODE"
    fi
    final="$(render "$warn")"
    if [ "$final" != "$old" ]; then
      newtmp; b="$NEWTMP"; printf '%s\n' "$final" > "$b"
      write_block "$target" "$b"
    fi
    echo "CHANGED=$changed"
    [ -z "$echo_major" ] || echo "$echo_major"
    [ -z "$echo_mode" ] || echo "$echo_mode"
    ;;
esac
exit 0
