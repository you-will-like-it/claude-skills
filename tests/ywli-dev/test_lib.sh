#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
. "$ROOT/plugins/ywli-dev/scripts/lib.sh"

F="$FIXTURES_DIR"

# ssva_lock_version
assert_eq "5.4.3" "$(ssva_lock_version "$F/ss5/composer.lock" silverstripe/framework)" "lock version ss5"
assert_eq "5.4.3" "$(ssva_lock_version "$F/crlf-ss5/composer.lock" silverstripe/framework)" "lock version crlf"
assert_eq "v5.4.3" "$(ssva_lock_version "$F/versions-odd/composer.lock" silverstripe/framework)" "lock version v-prefix"
assert_eq "" "$(ssva_lock_version "$F/ss5/composer.lock" no/such-package)" "lock version missing pkg"
assert_eq "" "$(ssva_lock_version "$F/nonexistent.lock" silverstripe/framework)" "lock version missing file"
assert_exit 0 ssva_lock_version "$F/nonexistent.lock" x/y

# ssva_installed_version
assert_eq "$(ssva_lock_version "$F/ss5/composer.lock" silverstripe/framework)" \
  "$(ssva_installed_version "$F/ss5/composer.lock" silverstripe/framework)" "installed_version same parser"

# ssva_major
assert_eq "5" "$(ssva_major v5.4.3)" "major v5.4.3"
assert_eq "5" "$(ssva_major 5.x-dev)" "major 5.x-dev"
assert_eq "" "$(ssva_major dev-main)" "major dev-main"
assert_eq "6" "$(ssva_major 6.0.0-beta1)" "major beta"
assert_eq "12" "$(ssva_major 12.1)" "major two digits"
assert_eq "" "$(ssva_major '')" "major empty"

# ssva_require_constraint
assert_eq '^6.0' "$(ssva_require_constraint "$F/ss6/composer.json" silverstripe/recipe-cms)" "require ss6"
assert_eq "" "$(ssva_require_constraint "$F/ss6/composer.json" no/such)" "require missing"
assert_eq "" "$(ssva_require_constraint "$F/nonexistent.json" a/b)" "require missing file"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/ssva.XXXXXX")"
printf '{\r\n    "require": {\r\n        "php": "^8.1"\r\n    },\r\n    "require-dev": {\r\n        "silverstripe/framework": "^5 || ^6"\r\n    }\r\n}\r\n' > "$tmp/composer.json"
assert_eq '^5 || ^6' "$(ssva_require_constraint "$tmp/composer.json" silverstripe/framework)" "require-dev + CRLF"
printf '{\n    "name": "silverstripe/framework",\n    "require": {\n        "php": "^8.1"\n    }\n}\n' > "$tmp/c2.json"
assert_eq "" "$(ssva_require_constraint "$tmp/c2.json" silverstripe/framework)" "name field is not a requirement"
rm -rf "$tmp"

# ssva_constraint_majors
assert_eq "5 6" "$(ssva_constraint_majors '^5 || ^6')" "cm ^5 || ^6"
assert_eq "5 6" "$(ssva_constraint_majors '^5|^6')" "cm single pipe"
assert_eq "5" "$(ssva_constraint_majors '~5.4')" "cm ~5.4"
assert_eq "6" "$(ssva_constraint_majors '6.*')" "cm 6.*"
assert_eq "4" "$(ssva_constraint_majors '>=4.13 <6')" "cm range"
assert_eq "5" "$(ssva_constraint_majors '5.4.3')" "cm exact"
assert_eq "6" "$(ssva_constraint_majors '^6.0@dev')" "cm @dev"
assert_eq "" "$(ssva_constraint_majors '*')" "cm star"
assert_eq "" "$(ssva_constraint_majors '')" "cm empty"
assert_eq "4 5" "$(ssva_constraint_majors '^5.0 || ^4.13')" "cm sorted"
assert_eq "5" "$(ssva_constraint_majors '^5.0 || ~5.4')" "cm unique"
assert_eq "5" "$(ssva_constraint_majors '>=5.0,<6.0')" "cm comma"
assert_eq "5" "$(ssva_constraint_majors 'v5.4.3')" "cm v-prefix"
assert_eq "5" "$(ssva_constraint_majors '5.x-dev')" "cm 5.x-dev"
assert_eq "" "$(ssva_constraint_majors 'dev-main')" "cm dev-main"
assert_eq "4" "$(ssva_constraint_majors '^4.13 !=4.14')" "cm !="

assert_eq "4" "$(ssva_constraint_majors '>= 4.13 < 6')" "cm spaced operators"
assert_eq "5" "$(ssva_constraint_majors '>= 5.0')" "cm spaced >="

# ssva_lock_version: nested require must not shadow the real package object
tmp="$(mktemp -d "${TMPDIR:-/tmp}/ssva.XXXXXX")"
cat > "$tmp/composer.lock" <<'LOCK'
{
    "packages": [
        {
            "name": "some/module",
            "version": "1.0.0",
            "require": {
                "silverstripe/framework": "^5"
            }
        },
        {
            "name": "silverstripe/framework",
            "version": "5.4.3"
        }
    ]
}
LOCK
assert_eq "5.4.3" "$(ssva_lock_version "$tmp/composer.lock" silverstripe/framework)" "lock nested require regression"
rm -rf "$tmp"

# ssva_recipe_to_ss_major
assert_eq "4" "$(ssva_recipe_to_ss_major 1)" "recipe 1 -> 4"
assert_eq "5" "$(ssva_recipe_to_ss_major 5)" "recipe 5"
assert_eq "6" "$(ssva_recipe_to_ss_major 6)" "recipe 6"
assert_eq "" "$(ssva_recipe_to_ss_major '')" "recipe empty"

# ssva_strip_cr
assert_eq "ab" "$(printf 'a\r\nb' | { f="$(mktemp)"; cat > "$f"; ssva_strip_cr "$f" | tr -d '\n'; rm -f "$f"; })" "strip_cr"

finish
