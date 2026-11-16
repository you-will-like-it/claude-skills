#!/usr/bin/env bash
# Runs every tests/test_*.sh in its own bash process.
# The interpreter is SSVA_BASH, defaulting to the bash running this script ($BASH), so
#   /path/to/bash-3.2 tests/run.sh      and      SSVA_BASH=/path/to/bash-3.2 bash tests/run.sh
# both run the test files AND every plugin script they call under that bash (tests call scripts
# through "$SSVA_BASH"; tests/lib.sh puts it first on PATH for nested `bash` calls in the scripts).
DIR="$(cd "$(dirname "$0")" && pwd)"
SSVA_BASH="${SSVA_BASH:-$BASH}"
case "$SSVA_BASH" in */*) ;; *) SSVA_BASH="$(command -v "$SSVA_BASH")" ;; esac
[ -x "$SSVA_BASH" ] || { echo "run.sh: SSVA_BASH is not executable: $SSVA_BASH" >&2; exit 2; }
export SSVA_BASH
echo "bash: $("$SSVA_BASH" -c 'echo "$BASH_VERSION"') ($SSVA_BASH)"
pass=0; fail=0; failed=""
for t in "$DIR"/test_*.sh; do
  [ -e "$t" ] || continue
  name="$(basename "$t")"
  out="$("$SSVA_BASH" "$t" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "PASS $name"; pass=$((pass+1))
  else
    echo "FAIL $name"; echo "$out" | sed 's/^/    /'
    fail=$((fail+1)); failed="$failed $name"
  fi
done
echo "---"
echo "Passed: $pass  Failed: $fail"
[ "$fail" -eq 0 ] || { echo "Failed:$failed"; exit 1; }
exit 0
