# Board

Who is working on what, and messages between chats. Read it when you start and whenever you pull; update it
before you push. Newest entries first in each section. Keep entries to one or two lines; detail goes in the
lane's own docs. Decisions are not made here: they live in ai-business-ideas `ideas/game-modernizer.md`.

## Lanes

| Lane | Chat | Runs where | Owns |
|---|---|---|---|
| Main (M6 coverage, later differential checks) | chat 19 | Claude Code on Jeremy's PC, lab `/home/claude/lab` | `scripts/dev/`, `tools/` coverage and report scripts, `tools/plans/`, `docs/coverage*.md`, `docs/cover-fights.md`; also `scripts/main.gd` and `scripts/ecl_vm.gd` (shared core: see CLAUDE.md) |
| Side (Jeremy's play feedback, combat fidelity, QoL) | side chat 3 | Cloud, its own lab | `scripts/combat/`, `scripts/ui/`, screens (`*_screen.gd`, `party_menu.gd`, `character_sheet.gd`), fight tools (`cmpfight*`, `trace.py`, `seed.py`, `regress.sh`), Test List sections it adds |
| Design office | discussion chats | claude.ai | no code; proposals and Jeremy's decisions |

Files not listed: whoever needs them asks here first.

## Now

- Main: chat 19 starting on the local lab (lab18). First: setup check, then 4:10 -all, 6:1's last flag, 3:8's commissions.
- Side: side chat 3 (fill in).

## Requests to another lane

Format: `date · from → to · what · status (open / taken / done)`

- 2026-11-14 · design → main · Load test: does a coverage run's diverged count rise with load (2:15 alone x3 vs at P=10)? If so, find where real time still affects a run. · open

## Findings for everyone

- 2026-11-14 · main (chat 18) · Variants of one area share `cov_<area>.json`; keep them in one lane, or the last to save wins.
- 2026-11-14 · main (chat 18) · The ECL16.DAX errors were the bot's travel graph, not the engine; covsum.sh now prints SCRIPT ERROR counts. Any SCRIPT ERROR goes here.
- 2026-11-14 · design · Godot `.uid` files: one commit adds them all (pending, done when both chats are idle). After it, commit a new script's `.uid` with the script.
