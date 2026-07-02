---
name: linear-pr-guard
description: Use before opening any pull request (gh pr create, the GitHub web UI, or any PR flow) - ensures an approved Linear ticket exists and is referenced in the PR, and that the work is logged in Linear. Pairs with the linear-pr-guard hook that intercepts `gh pr create`.
---

# Linear PR Guard

**Every pull request must have an associated Linear ticket.** A PR with no ticket is untracked, unloggable work.

## When to use

Before opening any PR — whether via `gh pr create`, the GitHub web UI, or an editor/integration. Invoke this the moment PR creation becomes likely, not after the command is typed.

## Procedure

1. **Check for a ticket.** Determine whether the current work already has an associated Linear ticket — look at the branch name, commit trailers, the task you were handed, or ask the human directly.
2. **If none exists, get approval FIRST.** Prompt the human to approve creating a ticket. Do not create one silently.
3. **Create it once approved** via the Linear MCP server (its create/save-issue tool, however that server is named in your config) with a clear title and a short description of the work and its scope.
4. **Size it.** Propose a t-shirt size on the scale below and set it on the ticket. If it comes out an **XL**, do not file it as-is — break it into smaller cards first.
5. **Reference it in the PR.** Put the ticket key (e.g. `ENG-123`) in the PR title and/or body so Linear auto-links the PR to the ticket.
6. **Log the work.** Keep the ticket updated as the work progresses — we log almost all work in Linear.

## Sizing — t-shirt sizes

Size each ticket by effort. Propose a size, then refine it with the human.

| Size | Effort | What it looks like |
| --- | --- | --- |
| XS | A few hours | Straightforward change, minimal review risk. |
| S | 1 day | One area (backend, frontend, etc.) or light work across two. Standard PR. |
| M | 2–3 days | Multiple areas. |
| L | 3–4 days | Multiple areas; needs coordination or design decisions. |
| XL | More than a week | **Too big — break it down.** This is a signal, not a valid size. |

**Never file an XL** — it means the work is too big and must be split into smaller cards before opening a PR. If you genuinely can't size it, say so and ask rather than guessing.

## Backstop and its limits

This skill ships alongside a `PreToolUse` hook that intercepts `gh pr create` and forces an "ask" confirmation prompt.

Treat that prompt as a **reminder, not a verifier**:

- It matches on the literal command string, so it also fires on harmless commands that merely mention `gh pr create` (e.g. `echo "gh pr create"`). Approve those.
- It **cannot** confirm a ticket actually exists — that is your job, via the procedure above.
- It only guards the **CLI path**. PRs opened through the GitHub web UI or an integration never touch the hook, so the procedure above is what covers them.
