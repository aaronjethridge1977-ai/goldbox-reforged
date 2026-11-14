# Board

Who is working on what, and messages between chats. Read it when you start and whenever you pull; update it
before you push. Newest entries first in each section. Keep entries to one or two lines; detail goes in the
lane's own docs. Decisions are not made here: they live in ai-business-ideas `ideas/game-modernizer.md`.

## Lanes

| Lane | Chat | Runs where | Owns |
|---|---|---|---|
| Main (M6 coverage, later differential checks) | chat 19 | Claude Code on Jeremy's PC, lab `/home/claude/lab` | `scripts/dev/`, `tools/` coverage and report scripts, `tools/plans/`, `docs/coverage*.md`, `docs/cover-fights.md`; also `scripts/main.gd` and `scripts/ecl_vm.gd` (shared core: see CLAUDE.md) |
| Side (Jeremy's play feedback, combat fidelity, QoL) | side chat 4 | Cloud, its own lab | `scripts/combat/`, `scripts/ui/`, screens (`*_screen.gd`, `party_menu.gd`, `character_sheet.gd`), fight tools (`cmpfight*`, `trace.py`, `seed.py`, `regress.sh`), Test List sections it adds |
| Design office | discussion chats | claude.ai | no code; proposals and Jeremy's decisions |

Files not listed: whoever needs them asks here first.

## Now

- Main: chat 19 starting on the local lab (lab18). First: setup check, then 4:10 -all, 6:1's last flag, 3:8's commissions.
- Side: side chat 4 on P16 combat animations (display only, off in headless/--play/--keys/--fast; lab key `--anim`). Steps 2-3 done: messages paced as the original, DONE -> SPEED; computer turns step by step with the original's view rule (GAME.OVR 0x30F0E). Next: missiles.

## Requests to another lane

Format: `date · from → to · what · status (open / taken / done)`

- 2026-11-14 · design → main · Re-take the reference-check baseline (`refcheck.sh`, `data/refcheck_base.txt`) on current main, noted as the first after A1; say whether chat 18's baseline came before or after A1 landed. · open
- 2026-11-14 · design → main · Move the side lane's lab keys (`_replay_keys`: `fightend`, `partyhp`, `memorize=`, `order=`, `smartquick`, `smartmonsters`) out of `main.gd` into a side-owned hook file (e.g. `scripts/combat/lab_hooks.gd`, its `.uid` with it); `main.gd` keeps one call into it. Do it when the side lane isn't mid-change there; post here when done. (Decided 2026-11-14, Methods 2.) · open
- 2026-11-14 · design → main · `tools/lab/README.md`: a one-page "Current method" section at the top; the "Chat N additions" stay below as history. Draft ready: ai-business-ideas `plans/lab-current-method-draft.md` (fill the [check] lines, paste, delete the draft). · open
- 2026-11-14 · design → main · CLAUDE.md "Ending a chat": the dated entry now goes at the top of ai-business-ideas `plans/chat-log.md`, not `ideas/game-modernizer.md`. · open
- 2026-11-14 · design → main · Load test: does a coverage run's diverged count rise with load (2:15 alone x3 vs at P=10)? If so, find where real time still affects a run. Note memory and swap during the P=10 run. · open

## Rule changes

Any push that changes game behaviour (rules, dice, fight outcomes), not just the display, adds a line here in the same
push: what changed and what it may affect. Other lanes re-take their baselines (the reference check first).
Format: `date · lane (chat) · change · may affect`

- 2026-11-14 · side (chat 3) · A1: the original's turn order and spell choice in all fights; CONTINUE BATTLE when every enemy is down but not dead; worthless monster items on a d10 of 1-3 · the bot's real fights, flee jobs, story run, refcheck baseline

## Findings for everyone

- 2026-11-14 · design · Decided (Methods 2): a QoL feature may change a screen, in the original's own style (font, colours, frame, menu wording and keys; new items after the original ones), with a mockup for Jeremy first; with the feature off in SETTINGS the screen is exactly the original's. Replaces the 2026-11-12 "every screen matches" rule.
- 2026-11-14 · design · ai-business-ideas reorganized: chat logs now in `plans/chat-log.md` (newest first; add your end-of-chat entry at the top); `ideas/game-modernizer.md` keeps decisions and a short Next step. New team rules (Methods 2, dated entry): side-lane hook file, the Rule changes section above, and when an area and M6 coverage close.
- 2026-11-14 · side (chat 3) · Shared core touched today, all small: main.gd's `_replay_keys` lab keys `fightend`, `partyhp`, `memorize=`, `order=`, `smartquick`, `smartmonsters`, and `Spoils.gather`'s new 4th argument in `_after_fight` (ECL 0x6DE3). No ecl_vm.gd changes.
- 2026-11-14 · side (chat 3) · A1 (decided): every fight now uses the original's turn order and spell choice, so the bot's real fights can play out differently. A fight with every enemy down but not dead now plays out the round and asks CONTINUE BATTLE (the bot answers N); shortcut wins set `Combat.decided`. Worthless monster items reach the pile only on a d10 of 1-3.

- 2026-11-14 · main (chat 18) · Variants of one area share `cov_<area>.json`; keep them in one lane, or the last to save wins.
- 2026-11-14 · main (chat 18) · The ECL16.DAX errors were the bot's travel graph, not the engine; covsum.sh now prints SCRIPT ERROR counts. Any SCRIPT ERROR goes here.
- 2026-11-14 · design · Godot `.uid` files: one commit adds them all (pending, done when both chats are idle). After it, commit a new script's `.uid` with the script.
