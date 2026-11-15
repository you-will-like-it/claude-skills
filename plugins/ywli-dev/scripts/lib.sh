#!/usr/bin/env bash
# ss-version-aware: version parsing primitives. SOURCE this file; it executes nothing.
# bash 3.2 / BSD awk+sed compatible. All functions print to stdout and return 0.
# Assumes pretty-printed composer JSON (one key per line), as Composer writes it.

# ssva_strip_cr <file>: cat with \r removed.
ssva_strip_cr() {
  [ -f "$1" ] || return 0
  tr -d '\r' < "$1"
}

# ssva_lock_version <lockfile> <package>: version of first "name": "<package>" entry.
ssva_lock_version() {
  [ -f "$1" ] || return 0
  ssva_strip_cr "$1" | awk -v pkg="$2" '
    BEGIN { target = "\"name\": \"" pkg "\"" }
    /"name"[ \t]*:/ { found = (index($0, target) > 0) ; next }
    found && /"version"[ \t]*:/ {
      n = split($0, p, "\"")
      print p[4]
      exit
    }
  '
  return 0
}

# ssva_installed_version <installed.json> <package>: same format handling as lock.
ssva_installed_version() {
  ssva_lock_version "$1" "$2"
}

# ssva_major <version>: first digit run, or empty.
ssva_major() {
  printf '%s\n' "$1" | sed -E -n 's/^[^0-9]*([0-9]+).*$/\1/p' | head -n 1
  return 0
}

# ssva_require_constraint <composer.json> <package>: constraint from require/require-dev.
ssva_require_constraint() {
  [ -f "$1" ] || return 0
  ssva_strip_cr "$1" | awk -v pkg="$2" '
    /^[ \t]*"require(-dev)?"[ \t]*:[ \t]*\{[ \t]*$/ { insec = 1; next }
    insec && /^[ \t]*\}/ { insec = 0; next }
    insec {
      n = split($0, p, "\"")
      if (n >= 4 && p[2] == pkg) { print p[4]; exit }
    }
  '
  return 0
}

# ssva_constraint_majors <constraint>: ascending unique lower-bound majors, space-separated.
ssva_constraint_majors() {
  printf '%s\n' "$1" | sed -E 's/@[A-Za-z]+//g; s/\|\|?/;/g; s/,/ /g' | awk '
    {
      na = split($0, alts, ";")
      for (i = 1; i <= na; i++) {
        nt = split(alts[i], tok, /[ \t]+/)
        skipnext = 0
        for (j = 1; j <= nt; j++) {
          t = tok[j]
          if (t == "") continue
          if (t == "-") { skipnext = 1; continue }      # hyphen range: next token is upper bound
          if (skipnext) { skipnext = 0; continue }
          if (t ~ /^(<|<=|!=|!)$/) { skipnext = 1; continue }  # lone operator: next token is its operand, skip
          if (t ~ /^(<|!)/) continue                     # upper bound / exclusion
          sub(/^(>=|>|=|\^|~|v|V)+/, "", t)
          if (t ~ /^[0-9]/) {
            sub(/[^0-9].*$/, "", t)
            seen[t + 0] = 1
          }
        }
      }
    }
    END { for (m in seen) print m }
  ' | sort -n | tr '\n' ' ' | sed -E 's/ +$//'
  echo
  return 0
}

# ssva_recipe_to_ss_major <recipe-major>: 1 -> 4 (SS4-era recipes), else identity.
ssva_recipe_to_ss_major() {
  if [ "$1" = "1" ]; then echo 4; else echo "$1"; fi
  return 0
}

# ssva_add_exclude <dir> <path-relative-to-dir>: append "/<repo-relative path>" to the
# repo's info/exclude (the only git-level write this plugin makes). Idempotent.
# No-op outside git. Never touches .gitignore or tracked files.
ssva_add_exclude() {
  local dir="$1" rel="$2" p ex prefix entry
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  p="$(git -C "$dir" rev-parse --git-path info/exclude 2>/dev/null)" || return 0
  case "$p" in /*) ex="$p" ;; *) ex="$dir/$p" ;; esac
  prefix="$(git -C "$dir" rev-parse --show-prefix 2>/dev/null)"
  entry="/$prefix$rel"
  mkdir -p "$(dirname "$ex")" || return 0
  if [ -f "$ex" ] && grep -qxF -- "$entry" "$ex"; then return 0; fi
  if [ -s "$ex" ] && [ -n "$(tail -c 1 "$ex")" ]; then printf '\n' >> "$ex"; fi
  printf '%s\n' "$entry" >> "$ex"
  return 0
}
