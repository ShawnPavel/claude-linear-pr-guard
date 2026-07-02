#!/usr/bin/env bash
set -euo pipefail

# Smoke tests for Linear PR Guard. Run from anywhere: ./test.sh
# Needs: bash, jq, grep. Exits nonzero on the first failure.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_JSON="$ROOT/plugins/linear-pr-guard/hooks/hooks.json"
FAILED=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1" >&2; FAILED=1; }

# --- 1. JSON files parse ---
for f in "$ROOT/.claude-plugin/marketplace.json" \
         "$ROOT/plugins/linear-pr-guard/.claude-plugin/plugin.json" \
         "$HOOKS_JSON"; do
  if jq -e . "$f" >/dev/null 2>&1; then pass "valid JSON: ${f#"$ROOT"/}"; else fail "invalid JSON: $f"; fi
done

# --- 2. Skill has frontmatter ---
SKILL="$ROOT/plugins/linear-pr-guard/skills/linear-pr-guard/SKILL.md"
if head -5 "$SKILL" | grep -q '^name: linear-pr-guard'; then pass "skill frontmatter"; else fail "skill frontmatter missing"; fi

# --- 3. Hook behavior (the command exactly as shipped in hooks.json) ---
CMD="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOOKS_JSON")"

run_hook() { printf '%s' "$1" | bash -c "$CMD"; }

out="$(run_hook '{"tool_input":{"command":"gh pr create --fill"}}')"
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)" = "ask" ] \
  && pass "asks on gh pr create" || fail "no ask on gh pr create"

out="$(run_hook '{"tool_input":{"command":"cd repo && gh  pr create --title x"}}')"
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)" = "ask" ] \
  && pass "asks on compound command" || fail "no ask on compound command"

out="$(run_hook '{"tool_input":{"command":"git status"}}')"
[ -z "$out" ] && pass "silent on unrelated command" || fail "false positive on git status"

out="$(run_hook '{"tool_input":{"command":"git status","description":"prep before gh pr create"}}')"
[ -z "$out" ] && pass "silent when only the description mentions the phrase (jq path)" \
  || fail "false positive on description field"

# --- 4. Fallback path without jq (sandbox PATH with only bash/cat/grep) ---
SB="$(mktemp -d)"
resolve() { env -i PATH=/usr/bin:/bin sh -c "command -v $1"; }
ln -s "$(resolve grep)" "$SB/grep"; ln -s "$(resolve cat)" "$SB/cat"; ln -s "$(resolve bash 2>/dev/null || echo /bin/bash)" "$SB/bash"
out="$(printf '%s' '{"tool_input":{"command":"gh pr create"}}' | env PATH="$SB" "$SB/bash" -c "$CMD")"
printf '%s' "$out" | "$SB/grep" -q '"permissionDecision":"ask"' \
  && pass "no-jq fallback still asks on real match" || fail "no-jq fallback missed a real match"
rm -rf "$SB"

# --- 5. install.sh: fresh install, idempotency, skill copy ---
TMPHOME="$(mktemp -d)"
S="$TMPHOME/settings.json"
CLAUDE_SETTINGS="$S" bash "$ROOT/install.sh" >/dev/null
jq -e . "$S" >/dev/null && pass "install.sh writes valid settings" || fail "install.sh wrote invalid JSON"
[ -f "$TMPHOME/skills/linear-pr-guard/SKILL.md" ] && pass "install.sh copies skill" || fail "skill not copied"
CLAUDE_SETTINGS="$S" bash "$ROOT/install.sh" >/dev/null
n="$(jq '[.hooks.PreToolUse[].hooks[].command | select(test("Linear guard"))] | length' "$S")"
[ "$n" = "1" ] && pass "install.sh is idempotent" || fail "duplicate hooks after re-run (count=$n)"
rm -rf "$TMPHOME"

[ "$FAILED" = "0" ] && echo "all tests passed" || { echo "TESTS FAILED" >&2; exit 1; }
