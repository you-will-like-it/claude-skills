#!/usr/bin/env bash
# SessionStart hook: refresh the ss-version-aware block; report major/mode changes.
# Never fails, never writes to stderr, prints nothing unless a change must be reported.
exec 2>/dev/null
HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

[ -d "$DIR" ] || exit 0
[ "$(git -C "$DIR" rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ] || exit 0

res="$(bash "$HERE/block.sh" refresh "$DIR" 2>/dev/null)" || true

major=""; mode=""
while IFS= read -r line; do
  line="${line%$'\r'}"
  case "$line" in
    MAJOR_CHANGED=*) major="${line#MAJOR_CHANGED=}" ;;
    MODE_CHANGED=*) mode="${line#MODE_CHANGED=}" ;;
  esac
done <<EOT
$res
EOT

if [ -n "$major" ]; then v="$major"; elif [ -n "$mode" ]; then v="$mode"; else exit 0; fi
old="${v%%->*}"; new="${v#*->}"

esc() { # escape backslash and double quote
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}
msg="ss-version-aware: verzija promijenjena $(esc "$old") → $(esc "$new"); blok osvježen."
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg"
exit 0
