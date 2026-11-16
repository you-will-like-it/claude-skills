#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
DETECT="$ROOT/plugins/ywli-dev/scripts/detect.sh"
F="$FIXTURES_DIR"

run() { "$SSVA_BASH" "$DETECT" "$F/$1" 2>/dev/null; }
has() { # fixture line
  assert_contains "
$(run "$1")
" "
$2
" "$1: $2"
}

# ss6
has ss6 "SS_PROJECT=project"
has ss6 "SS_VERSION=6.1.2"
has ss6 "SS_MAJOR=6"
has ss6 "SS_MODE=normal"
has ss6 "SS_VENDOR_MISMATCH=0"
has ss6 "BUILD_TOOL=vite"
has ss6 "PHP_VERSION=8.3"
has ss6 "DDEV=1"
assert_contains "$(run ss6)" "dnadesign/silverstripe-elemental=6.0.1" "ss6 modules"
assert_contains "$(run ss6)" "SS_MODULES=silverstripe/cms=" "ss6 modules order"

# exact key order
assert_eq "SS_PROJECT SS_VERSION SS_MAJOR SS_MODE SS_TARGET_MAJOR SS_COMPAT_MAJORS SS_VENDOR_MISMATCH SS_MODULES PHP_VERSION BUILD_TOOL DDEV LOCK_HASH" \
  "$(run ss6 | sed 's/=.*//' | tr '\n' ' ' | sed 's/ $//')" "key order"
assert_eq "12" "$(run ss6 | wc -l | tr -d ' ')" "12 lines"
case "$(run ss6 | grep '^SS_MODULES=')" in *,) _fail "trailing comma" "none" "trailing" ;; esac

# ss5
has ss5 "SS_MAJOR=5"
has ss5 "BUILD_TOOL=webpack"
# ss4 recipe 1
has ss4-recipe1 "SS_MAJOR=4"
has ss4-recipe1 "SS_MODE=normal"
has ss4 "SS_MAJOR=4"
# ss3
has ss3-nocomposer "SS_PROJECT=project"
has ss3-nocomposer "SS_VERSION=3.6.1"
has ss3-nocomposer "SS_MAJOR=3"
has ss3-nocomposer "LOCK_HASH=nolock"
has ss3-nocomposer "SS_MODULES="
has ss3-composer "SS_MAJOR=3"
has ss3-composer "SS_MODE=normal"
# upgrade
has upgrade-5-6 "SS_MODE=upgrade"
has upgrade-5-6 "SS_MAJOR=5"
has upgrade-5-6 "SS_TARGET_MAJOR=6"
has upgrade-5-6 "SS_VENDOR_MISMATCH=0"
# vendor stale
has vendor-stale "SS_MODE=upgrade"
has vendor-stale "SS_VENDOR_MISMATCH=1"
has vendor-stale "SS_MAJOR=5"
has vendor-stale "SS_VERSION=5.4.3"
has vendor-stale "SS_TARGET_MAJOR=6"
# module
has module-compat "SS_PROJECT=module"
has module-compat "SS_MODE=compat"
has module-compat "SS_COMPAT_MAJORS=5 6"
has module-compat "SS_MAJOR=6"
has module-compat "SS_VERSION=^5 || ^6"
has module-compat "LOCK_HASH=nolock"
has module-single "SS_PROJECT=module"
has module-single "SS_MODE=normal"
has module-single "SS_MAJOR=6"
has module-single "SS_COMPAT_MAJORS="
# none
has notss "SS_PROJECT=none"
has notss "SS_MODE=normal"
has notss "SS_VENDOR_MISMATCH=0"
has notss "SS_MAJOR="
assert_eq "12" "$(run notss | wc -l | tr -d ' ')" "none: 12 lines"
assert_contains "$("$SSVA_BASH" "$DETECT" /nonexistent/dir 2>/dev/null)" "SS_PROJECT=none" "missing dir"
assert_exit 0 "$SSVA_BASH" "$DETECT" /nonexistent/dir
assert_exit 0 "$SSVA_BASH" "$DETECT" "$F/notss"
# dev
has versions-dev "SS_MAJOR=unknown"
has versions-dev "SS_VERSION=dev-main"
has versions-dev "SS_MODE=normal"
assert_exit 0 "$SSVA_BASH" "$DETECT" "$F/versions-dev"
has versions-odd "SS_MAJOR=5"
has versions-odd "SS_MODE=normal"
# crlf == ss5 except LOCK_HASH
assert_eq "$(run ss5 | grep -v '^LOCK_HASH=')" "$(run crlf-ss5 | grep -v '^LOCK_HASH=')" "crlf-ss5 same as ss5"
# default dir = PWD
assert_contains "$(cd "$F/ss6" && "$SSVA_BASH" "$DETECT" 2>/dev/null)" "SS_MAJOR=6" "default PWD"
# LOCK_HASH from git
assert_eq "$(git hash-object "$F/ss6/composer.lock")" "$(run ss6 | sed -n 's/^LOCK_HASH=//p')" "lock hash"
# build tool precedence: vite wins
tmp="$(mktemp -d "${TMPDIR:-/tmp}/ssd.XXXXXX")"
cp -R "$F/ss5/." "$tmp/"; : > "$tmp/vite.config.ts"
assert_contains "$("$SSVA_BASH" "$DETECT" "$tmp")" "BUILD_TOOL=vite" "vite wins"
rm -rf "$tmp"
# package.json without a vite/webpack config -> npm; config wins over npm; nothing -> none
tmp="$(mktemp -d "${TMPDIR:-/tmp}/ssd.XXXXXX")"
cp -R "$F/upgrade-5-6/." "$tmp/"; printf '{\n  "name": "x"\n}\n' > "$tmp/package.json"
assert_contains "$("$SSVA_BASH" "$DETECT" "$tmp")" "BUILD_TOOL=npm" "package.json only -> npm"
: > "$tmp/webpack.config.js"
assert_contains "$("$SSVA_BASH" "$DETECT" "$tmp")" "BUILD_TOOL=webpack" "webpack config wins over npm"
rm -f "$tmp/webpack.config.js" "$tmp/package.json"
assert_contains "$("$SSVA_BASH" "$DETECT" "$tmp")" "BUILD_TOOL=none" "no package.json -> none"
rm -rf "$tmp"
# executable bit
[ -x "$DETECT" ] || _fail "detect.sh executable" "x" "not x"
finish
