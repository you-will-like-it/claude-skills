#!/usr/bin/env bash
# Fails if any *.sh under plugins/ or tests/ uses constructs unavailable in macOS bash 3.2 / BSD utils.
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SELF="$HERE/test_portability.sh"
found=0
files="$(find "$ROOT/plugins" "$ROOT/tests/ywli-dev" -name '*.sh' -type f 2>/dev/null | grep -v -F "$SELF")"
check() { # label, ERE
  local f hits
  for f in $files; do
    hits="$(grep -nE -- "$2" "$f" | grep -vE '^[0-9]+:[[:space:]]*#')"
    if [ -n "$hits" ]; then
      echo "$1: $(echo "$hits" | sed "s|^|$f:|")"; found=1
    fi
  done
}
# bash 3.2 uses \001 (CTLESC) and \177 (CTLNUL) internally: `IFS=<that byte> read` never splits on it.
# Any \001/\177 byte written as printf '\001', $'\001', \x01, \177, \x7f is flagged; use \037.
CTL_RE='\\(0?01|177)([^0-9]|$)|\\x0?1([^0-9a-fA-F]|$)|\\x7[fF]'
run_checks() {
  check "declare -A"      'declare[[:space:]]+-A'
  check "mapfile/readarray" '(^|[^[:alnum:]_])(mapfile|readarray)([^[:alnum:]_]|$)'
  check "case-mod expansion" '\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^)'
  check "sed -i without suffix" "sed[[:space:]]+-i([[:space:]]+[^'\"[:space:]]|[[:space:]]*\$|[[:space:]]+['\"][^'\"]*['\"])"
  check "grep -P"         'grep[[:space:]]+(-[A-Za-z]*P|--perl-regexp)'
  check "readlink -f"     'readlink[[:space:]]+-[A-Za-z]*f'
  check "\\001/\\177 as separator (bash 3.2 CTLESC/CTLNUL)" "$CTL_RE"
}

# self-test: the separator check must catch every spelling
T="$(mktemp -d "${TMPDIR:-/tmp}/ssport.XXXXXX")" || exit 1
saved="$files"
for s in "SEP=\"\$(printf '\\001')\"" "IFS=\$'\\001' read -r a b" "IFS=\$'\\x01' read -r a" "IFS=\$'\\177' read a" \
         "SEP=\"\$(printf '\\x7f')\"" "awk -F'\\001' x" "tr '\\000' '\\001'"; do
  printf '%s\n' "$s" > "$T/m.sh"; files="$T/m.sh"; found=0
  check "self" "$CTL_RE" >/dev/null
  [ "$found" = 1 ] || { echo "self-test: separator check missed: $s"; rm -rf "$T"; exit 1; }
done
for s in "SEP=\"\$(printf '\\037')\"" "sed 's/\\(a\\)/\\1/'" "printf '\\0'"; do
  printf '%s\n' "$s" > "$T/m.sh"; files="$T/m.sh"; found=0
  check "self" "$CTL_RE" >/dev/null
  [ "$found" = 0 ] || { echo "self-test: separator check false positive: $s"; rm -rf "$T"; exit 1; }
done
rm -rf "$T"; files="$saved"; found=0

run_checks
if [ "$found" -ne 0 ]; then echo "portability violations found"; exit 1; fi
exit 0
