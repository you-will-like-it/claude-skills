#!/usr/bin/env bash
# Test helpers. bash 3.2 compatible. Source from test_*.sh, call `finish` at the end.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$LIB_DIR/fixtures"
# Interpreter for the plugin scripts under test (tests/run.sh exports it; see there).
SSVA_BASH="${SSVA_BASH:-bash}"
# Private TMPDIR per test file: every fixture dir, mktemp and plugin temp file lands here and is
# removed on exit (do not set another EXIT trap in a test file).
_SSVA_TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ssva-test.XXXXXX")" || exit 1
TMPDIR="$_SSVA_TEST_TMP"; export TMPDIR
# A path-valued SSVA_BASH also becomes the bare `bash` on PATH, so nested `bash x.sh` calls inside the
# plugin scripts (block.sh -> detect.sh, session-start.sh -> block.sh) run under the same interpreter.
case "$SSVA_BASH" in
  */*) mkdir -p "$_SSVA_TEST_TMP/.bin" && ln -s "$SSVA_BASH" "$_SSVA_TEST_TMP/.bin/bash" && PATH="$_SSVA_TEST_TMP/.bin:$PATH" && export PATH ;;
esac
_ssva_test_cleanup() { rm -rf "$_SSVA_TEST_TMP"; }
trap _ssva_test_cleanup EXIT
_FAILS=0
_ASSERTS=0

_fail() { # msg expected actual
  _FAILS=$((_FAILS+1))
  echo "  ASSERT FAILED: $1" >&2
  echo "    expected: $2" >&2
  echo "    actual:   $3" >&2
}

assert_eq() { # expected actual msg
  _ASSERTS=$((_ASSERTS+1))
  [ "$1" = "$2" ] || _fail "${3:-assert_eq}" "$1" "$2"
}

assert_contains() { # haystack needle msg
  _ASSERTS=$((_ASSERTS+1))
  case "$1" in *"$2"*) ;; *) _fail "${3:-assert_contains}" "contains: $2" "$1" ;; esac
}

assert_not_contains() { # haystack needle msg
  _ASSERTS=$((_ASSERTS+1))
  case "$1" in *"$2"*) _fail "${3:-assert_not_contains}" "not contains: $2" "$1" ;; esac
}

assert_file_contains() { # file needle
  _ASSERTS=$((_ASSERTS+1))
  if [ ! -f "$1" ]; then _fail "assert_file_contains" "file $1 exists" "missing"; return; fi
  grep -qF -- "$2" "$1" || _fail "assert_file_contains $1" "contains: $2" "$(cat "$1")"
}

assert_exit() { # code cmd...
  local want="$1" got; shift
  _ASSERTS=$((_ASSERTS+1))
  "$@" >/dev/null 2>&1; got=$?
  [ "$want" = "$got" ] || _fail "assert_exit $*" "exit $want" "exit $got"
}

# make_git_fixture <fixture-name>: copy to temp dir, git init + commit, echo path.
make_git_fixture() {
  local src="$FIXTURES_DIR/$1" tmp
  [ -d "$src" ] || { echo "no such fixture: $1" >&2; return 1; }
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/ssfix.XXXXXX")" || return 1
  cp -R "$src/." "$tmp/" || return 1
  (
    cd "$tmp" || exit 1
    git init -q
    git config user.name "Test"
    git config user.email "test@example.com"
    git config core.autocrlf false
    git config core.safecrlf false
    git add -A
    git commit -q -m "fixture" --no-gpg-sign
  ) >/dev/null 2>&1 || { echo "git fixture setup failed" >&2; return 1; }
  echo "$tmp"
}

finish() {
  if [ "$_FAILS" -gt 0 ]; then
    echo "$_FAILS of $_ASSERTS assertions failed" >&2
    exit 1
  fi
  exit 0
}
