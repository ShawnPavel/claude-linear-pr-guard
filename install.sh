#!/usr/bin/env bash
set -euo pipefail

# Linear PR Guard — no-plugin installer.
#
# Installs a PreToolUse Bash hook (forces a confirmation before `gh pr create`, reminding
# you to attach an approved Linear ticket) and, when run from a git clone, the companion
# skill. Prefer the PLUGIN install if you use Claude Code plugins (see README.md); this
# script is for a no-plugin setup or for baking the guard into a project's checked-in
# .claude/settings.json for a whole team.
#
# Usage:
#   bash install.sh                 # personal: ~/.claude/settings.json  (+ ~/.claude/skills/)
#   CLAUDE_SETTINGS=.claude/settings.json bash install.sh   # this project, team-wide (commit it)

SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
CLAUDE_DIR="$(dirname "$SETTINGS")"
MARKER="Linear guard:"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required for this installer (macOS: brew install jq)." >&2
  echo "       Or use the plugin install instead — it needs no jq. See README.md." >&2
  exit 1
fi

mkdir -p "$CLAUDE_DIR"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  echo "error: $SETTINGS is not valid JSON; refusing to edit. Fix it and re-run." >&2
  exit 1
fi

# --- 1. Install the hook (idempotent) ---
if jq -e --arg m "$MARKER" '.. | .command? // empty | select(type=="string" and contains($m))' \
     "$SETTINGS" >/dev/null 2>&1; then
  echo "Hook already present in $SETTINGS — skipping."
else
  # Captured verbatim (no shell expansion) to avoid quoting hell.
  read -r -d '' CMD <<'EOF' || true
IN=$(cat); C="$IN"; command -v jq >/dev/null 2>&1 && C=$(printf '%s' "$IN" | jq -r '.tool_input.command // ""'); printf '%s' "$C" | grep -qiE 'gh[[:space:]]+pr[[:space:]]+create' && printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Linear guard: before opening this PR, confirm an associated Linear ticket exists (or create one) and that it is approved. Log all work in Linear."}}'; true
EOF
  CMD="${CMD%$'\n'}"

  TMP="$(mktemp)"
  jq --arg cmd "$CMD" '
    .hooks //= {} |
    .hooks.PreToolUse //= [] |
    .hooks.PreToolUse += [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": $cmd } ] } ]
  ' "$SETTINGS" > "$TMP"
  jq -e . "$TMP" >/dev/null      # verify result still parses before swapping in
  mv "$TMP" "$SETTINGS"
  echo "Installed hook into $SETTINGS."
fi

# --- 2. Install the companion skill (only possible when run from a clone) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
SKILL_SRC="${SCRIPT_DIR}/plugins/linear-pr-guard/skills/linear-pr-guard"
SKILL_DEST="${CLAUDE_DIR}/skills/linear-pr-guard"
if [ -n "${SCRIPT_DIR}" ] && [ -f "${SKILL_SRC}/SKILL.md" ]; then
  mkdir -p "$(dirname "$SKILL_DEST")"
  rm -rf "$SKILL_DEST"
  cp -R "$SKILL_SRC" "$SKILL_DEST"
  echo "Installed companion skill into $SKILL_DEST."
else
  echo "Note: companion skill not installed (run from a git clone, not curl|bash, to include it,"
  echo "      or use the plugin install which bundles it — see README.md)."
fi

echo
echo "Prerequisite reminder: the skill's create-a-ticket step needs the Linear MCP server"
echo "configured in Claude Code (the hook itself works without it). See README.md > Prerequisites."
echo
echo "Done. Restart Claude Code or run /hooks to load the hook into your current session."
