# Linear PR Guard

A Claude Code plugin that makes sure **every pull request has an associated, approved Linear ticket** before it's opened.

Two parts that work together:

1. **A hook** (`PreToolUse` on `Bash`) that intercepts `gh pr create` and forces an "ask" confirmation prompt — the enforcement.
2. **A skill** (`linear-pr-guard`) that has Claude proactively check for a ticket, get your approval to create one, create it via the Linear MCP, give it a t-shirt size (XS–XL), reference it in the PR, and log the work — the guidance.

The hook is the guard; the skill is the workflow. You want both.

---

## Prerequisites

- **Claude Code** (all install paths).
- **`git` + the `gh` CLI** — the whole point is guarding `gh pr create`.
- **The Linear MCP server** — needed *only* for the skill's create-a-ticket step; the hook works without it. Add Linear's remote MCP in Claude Code and authenticate, e.g.:
  ```
  claude mcp add --transport sse linear https://mcp.linear.app/sse
  ```
  then run `/mcp` to complete OAuth. Verify the current URL/transport against [Linear's official MCP docs](https://linear.app/docs) — it may change. If you already have Linear MCP, nothing to do.
- **`jq`** — only for the `install.sh` path (macOS: `brew install jq`). The plugin path needs no `jq`.

---

## Install — paste this to Claude (fastest; installs hook **and** skill)

Open Claude Code and paste this. Claude runs it for you:

> Set up "Linear PR Guard" for Claude Code by running these commands, then tell me to run `/hooks` or restart so it loads:
>
> ```
> git clone https://github.com/ShawnPavel/claude-linear-pr-guard /tmp/linear-pr-guard 2>/dev/null || git -C /tmp/linear-pr-guard pull
> bash /tmp/linear-pr-guard/install.sh
> ```

Installs the hook into `~/.claude/settings.json` and the skill into `~/.claude/skills/`. Requires `jq`. Restart Claude Code (or run `/hooks`) afterward so the hook loads into your session.

---

## Install — plugin (managed; cleanest uninstall; no jq)

You type these yourself — Claude can't run `/plugin` commands for you:

```
/plugin marketplace add ShawnPavel/claude-linear-pr-guard
/plugin install linear-pr-guard@shawnpavel
```

Restart or `/hooks` to load. Uninstall later with `/plugin uninstall linear-pr-guard@shawnpavel`.

---

## Install — manual / whole team (checked-in)

Bake the hook into a project's committed `.claude/settings.json` so everyone on the repo gets it:

```
CLAUDE_SETTINGS=.claude/settings.json bash install.sh   # from a clone; also drops the skill into .claude/skills/
```

Or paste the hook object into the `hooks.PreToolUse` array of a `settings.json` by hand:

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "grep -qiE 'gh[[:space:]]+pr[[:space:]]+create' && printf '%s' '{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"ask\",\"permissionDecisionReason\":\"Linear guard: before opening this PR, confirm an associated Linear ticket exists (or create one) and that it is approved. Log all work in Linear.\"}}'; true"
    }
  ]
}
```

---

## How it works

The hook receives the tool call as JSON on stdin. When `jq` is available it extracts just the command string; without `jq` it falls back to scanning the raw payload. Either way it `grep`s for `gh pr create`, and on a match prints a `permissionDecision: "ask"` object — which makes Claude Code prompt you before the command runs. No match → prints nothing → the command proceeds untouched. It exits `0` either way, so it never blocks unrelated Bash calls.

## Verify it's working

After installing and restarting (or `/hooks`), ask Claude to run a harmless command that contains the trigger phrase:

```
true # gh pr create
```

You should see a permission prompt citing the Linear guard. If the command runs without a prompt, the hook isn't loaded — run `/hooks` to check, or restart Claude Code.

## Sizing

When the skill creates a ticket it proposes a **t-shirt size** (XS / S / M / L / XL) for the work and won't file an **XL** without breaking it down first (XL means "more than a week — too big; split it"). The full table lives in the skill: `plugins/linear-pr-guard/skills/linear-pr-guard/SKILL.md`.

## Known limits (by design)

- **Checkpoint, not verifier.** It matches the command *string*, so it also fires on harmless commands that merely mention `gh pr create` (e.g. `echo "gh pr create"`) — just approve those. It cannot confirm a Linear ticket actually exists; the skill/human does that.
- **CLI only.** PRs opened via the GitHub web UI or an integration never hit the hook. The skill is what covers those paths.
- **Don't double-install.** Installing the plugin **and** running `install.sh` gives you two "ask" prompts per PR. Pick one.

## Uninstall

- Plugin: `/plugin uninstall linear-pr-guard@shawnpavel`
- Script: delete the `Linear guard:` hook object from your `settings.json`, and remove `~/.claude/skills/linear-pr-guard/` (or the project's `.claude/skills/linear-pr-guard/`).

## License

MIT — see [LICENSE](LICENSE).
