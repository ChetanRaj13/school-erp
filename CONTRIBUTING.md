# Contributing — School ERP

This project is worked on by multiple AI agents (Claude, Grok, Claude Code) across sessions,
plus the human developer. These rules come from things that actually went wrong on this
project, not generic advice — read them before making changes.

---

## 1. Verify "done" claims independently — don't take them at face value

This is the single most important lesson from this project's history. Across one session
alone, almost every "done" claim from an agent turned out to be either incomplete, not
actually pushed to GitHub, or subtly wrong in a way only caught by independently re-deriving
the real numbers or logic and checking.

What "verify independently" means in practice:
- **Code changes**: clone the real repo (or re-read the actual file) rather than trusting a
  description of the change.
- **Database logic**: re-run the underlying SQL/query logic yourself and check the numbers
  match, rather than trusting a summary of the result.
- **Deployed functions**: fetch the live deployed code back and diff it against what was
  intended, rather than trusting a deploy command's reported success (see
  `docs/edge_functions.md` — in-chat deploy-approval has been unreliable on this project
  specifically).
- **"This feature is missing"** reports: investigate before assuming a regression. One past
  case of "OMR and document extraction are gone" turned out to be nothing missing from the
  code at all — the real cause was backend services that had never once been run.

## 2. Check `docs/schema.md` before adding a migration

Migration numbering has collided more than once on this project (a would-be `0014` colliding
with a real pre-existing `0014`, `0009` living in the wrong nested folder, `0018` legitimately
used twice). Check the real current sequence in the repo, not just the highest number in your
local branch, before picking the next number.

## 3. Known Postgres gotchas

See `docs/schema.md` section 4 for the specific issues this project has hit (a `random()`
caching quirk in subqueries, a `NULL NOT IN (...)` role-check bypass, syntax issues with
`CREATE TABLE AS INSERT ... RETURNING` and array indexing). Worth a read before writing new
generation scripts or DB functions.

## 4. Don't bundle a write with an unproven verification query in the same transaction

A real transaction-rollback trap hit this project: bundling a real `INSERT` with a fragile
verification query in the same call silently rolled back the successful insert when the
verification query errored. Run verification as a separate step, after the write commits.

## 5. Multi-agent handoff

- `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` are synced agent context files — read the relevant
  one plus this file before starting work.
- Any AI without direct repo access (chat-based sessions) works from a standalone
  `context-handoff-brief.md` — see that file's own instructions for the update protocol
  (`NEW-UPDATE`) if you're working that way.
- Agents **with** real repo access (Claude Code, Grok with the repo open) should keep
  `.agent-log/SESSION_LOG.md` up to date directly — it's the append-only chronological record
  that the handoff brief can't maintain from outside the repo.
- This repo's persistent docs (`SECURITY.md`, `docs/tech_debt.md`, `docs/schema.md`, this
  file) are the durable source of truth — don't let real findings live only inside a
  session's chat history or a handoff file that isn't part of the repo.

## 6. Repo access model

Not every agent working on this project can push code directly. If you're a chat-based agent
without repo write access, changes go through the human developer running git commands, or
through an agent that does have repo access (Claude Code, Grok). Say so plainly rather than
implying a change has been made when it's only been drafted.
