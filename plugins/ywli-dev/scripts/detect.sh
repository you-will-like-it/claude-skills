#!/usr/bin/env bash
# ss-version-aware: detect SilverStripe version/mode. Usage: detect.sh [project_dir]
# Prints 12 KEY=value lines, always exits 0. bash 3.2 compatible; no php/jq/python.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

DIR="${1:-$PWD}"

SS_PROJECT=none; SS_VERSION=""; SS_MAJOR=""; SS_MODE=normal
SS_TARGET_MAJOR=""; SS_COMPAT_MAJORS=""; SS_VENDOR_MISMATCH=0
SS_MODULES=""; PHP_VERSION=""; BUILD_TOOL=none; DDEV=0; LOCK_HASH=nolock

emit() {
  printf 'SS_PROJECT=%s\nSS_VERSION=%s\nSS_MAJOR=%s\nSS_MODE=%s\nSS_TARGET_MAJOR=%s\nSS_COMPAT_MAJORS=%s\nSS_VENDOR_MISMATCH=%s\nSS_MODULES=%s\nPHP_VERSION=%s\nBUILD_TOOL=%s\nDDEV=%s\nLOCK_HASH=%s\n' \
    "$SS_PROJECT" "$SS_VERSION" "$SS_MAJOR" "$SS_MODE" "$SS_TARGET_MAJOR" "$SS_COMPAT_MAJORS" \
    "$SS_VENDOR_MISMATCH" "$SS_MODULES" "$PHP_VERSION" "$BUILD_TOOL" "$DDEV" "$LOCK_HASH"
  exit 0
}

[ -d "$DIR" ] || emit

CJ="$DIR/composer.json"; LOCK="$DIR/composer.lock"; INST="$DIR/vendor/composer/installed.json"

# --- auxiliary keys (independent of project kind) ---
if [ -f "$DIR/.ddev/config.yaml" ]; then
  DDEV=1
  PHP_VERSION="$(ssva_strip_cr "$DIR/.ddev/config.yaml" | sed -n -E 's/^php_version:[ \t]*//p' | head -n 1 \
    | sed -E "s/[ \t]+#.*$//; s/^[\"']//; s/[\"'][ \t]*\$//; s/[ \t]+\$//")"
fi
BUILD_TOOL=none
for ext in js ts mjs cjs mts; do
  [ -f "$DIR/vite.config.$ext" ] && BUILD_TOOL=vite
done
if [ "$BUILD_TOOL" = none ]; then
  for f in "$DIR"/webpack.config.*; do
    [ -e "$f" ] && { BUILD_TOOL=webpack; break; }
  done
fi
# package.json without a vite/webpack config: plain npm scripts (spec §5.2)
[ "$BUILD_TOOL" = none ] && [ -f "$DIR/package.json" ] && BUILD_TOOL=npm
if [ -f "$LOCK" ]; then
  LOCK_HASH="$(git hash-object "$LOCK" 2>/dev/null)"
  [ -n "$LOCK_HASH" ] || LOCK_HASH=nolock
fi

# --- constraint source: framework, recipe-cms, recipe-core ---
CONSTRAINT=""; CONSTRAINT_MAJORS=""
for pkg in silverstripe/framework silverstripe/recipe-cms silverstripe/recipe-core; do
  c="$(ssva_require_constraint "$CJ" "$pkg")"
  if [ -n "$c" ]; then
    CONSTRAINT="$c"
    raw="$(ssva_constraint_majors "$c")"
    if [ "$pkg" = silverstripe/framework ]; then
      CONSTRAINT_MAJORS="$raw"
    else
      for m in $raw; do CONSTRAINT_MAJORS="$CONSTRAINT_MAJORS $(ssva_recipe_to_ss_major "$m")"; done
      CONSTRAINT_MAJORS="$(printf '%s\n' $CONSTRAINT_MAJORS | sort -n -u | tr '\n' ' ' | sed 's/ *$//')"
    fi
    break
  fi
done
HIGHEST=""
for m in $CONSTRAINT_MAJORS; do HIGHEST="$m"; done
NMAJ=0
for m in $CONSTRAINT_MAJORS; do NMAJ=$((NMAJ+1)); done

LOCK_FW="$(ssva_lock_version "$LOCK" silverstripe/framework)"

IS_MODULE=0
if [ -n "$CONSTRAINT" ] && { [ ! -f "$LOCK" ] || ssva_strip_cr "$CJ" | grep -q '"type"[[:space:]]*:[[:space:]]*"silverstripe-vendormodule"'; }; then
  IS_MODULE=1
fi

if [ "$IS_MODULE" = 1 ]; then
  SS_PROJECT=module
  SS_VERSION="$CONSTRAINT"
  SS_MAJOR="${HIGHEST:-unknown}"
  if [ "$NMAJ" -gt 1 ]; then
    SS_MODE=compat
    SS_COMPAT_MAJORS="$CONSTRAINT_MAJORS"
  fi
elif [ -n "$LOCK_FW" ]; then
  SS_PROJECT=project
  SS_VERSION="$LOCK_FW"
  LOCK_MAJOR="$(ssva_major "$LOCK_FW")"
  SS_MAJOR="${LOCK_MAJOR:-unknown}"
  if [ -n "$LOCK_MAJOR" ]; then
    if [ -n "$CONSTRAINT_MAJORS" ]; then
      case " $CONSTRAINT_MAJORS " in
        *" $LOCK_MAJOR "*) ;;
        *) SS_MODE=upgrade; SS_TARGET_MAJOR="$HIGHEST" ;;
      esac
    fi
    if [ -f "$INST" ]; then
      INST_FW="$(ssva_installed_version "$INST" silverstripe/framework)"
      INST_MAJOR="$(ssva_major "$INST_FW")"
      if [ -n "$INST_MAJOR" ] && [ "$INST_MAJOR" != "$LOCK_MAJOR" ]; then
        SS_MODE=upgrade; SS_VENDOR_MISMATCH=1
        SS_MAJOR="$INST_MAJOR"; SS_VERSION="$INST_FW"; SS_TARGET_MAJOR="$LOCK_MAJOR"
      fi
    fi
  fi
  for pkg in silverstripe/cms silverstripe/admin silverstripe/assets silverstripe/versioned \
             dnadesign/silverstripe-elemental tractorcow/silverstripe-fluent; do
    v="$(ssva_lock_version "$LOCK" "$pkg")"
    [ -n "$v" ] && SS_MODULES="${SS_MODULES:+$SS_MODULES,}$pkg=$v"
  done
elif [ -f "$DIR/framework/core/Core.php" ]; then
  SS_PROJECT=project
  v="$(ssva_strip_cr "$DIR/framework/silverstripe_version" 2>/dev/null | tr -d '[:space:]')"
  case "$v" in *[0-9]*) SS_VERSION="$v" ;; *) SS_VERSION="3.x" ;; esac
  SS_MAJOR=3
fi

emit
