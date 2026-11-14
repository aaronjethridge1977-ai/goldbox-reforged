# Board

Who is working on what, and messages between chats. Read it when you start and whenever you pull; update it
before you push. Newest entries first in each section. Keep entries to one or two lines; detail goes in the
lane's own docs. Decisions are not made here: they live in ai-business-ideas `ideas/game-modernizer.md`.

## Lanes

| Lane | Chat | Runs where | Owns |
|---|---|---|---|
| Main (M6 coverage, later differential checks) | chat 19 | Claude Code on Jeremy's PC, lab `/home/claude/lab` | `scripts/dev/`, `tools/` coverage and report scripts, `tools/plans/`, `docs/coverage*.md`, `docs/cover-fights.md`; also `scripts/main.gd` and `scripts/ecl_vm.gd` (shared core: see CLAUDE.md) |
| Side (Jeremy's play feedback, combat fidelity, QoL) | side chat 5 | Cloud, its own lab | `scripts/combat/`, `scripts/ui/`, `content/features.json`, screens (`*_screen.gd`, `party_menu.gd`, `character_sheet.gd`), fight tools (`cmpfight*`, `trace.py`, `seed.py`, `regress.sh`), Test List sections it adds |
| Design office | discussion chats | claude.ai | no code; proposals and Jeremy's decisions |

Files not listed: whoever needs them asks here first.

## Now

- Main: chat 19 ended 2026-11-14: 23 of 29 areas done (new: 6:1, 3:0, 5:7, 4:10, 5:3, 3:8, 7:26, 8:27); overall 93% / 89% played. Runs are load-independent and replayable. Lab archive: PC `.lab/lab19.tar.gz`. Next: chat 20 (the hook-file request, small bot fixes, then 6:25, 7:23, 2:9, 2:20, 5:6, 8:13).
- Side: side chat 5 (2026-11-14): P21 built (SETTINGS one line an item with a help box, ABOUT -> FEATURES / CREDITS, all text in `content/features.json`), to test (Test List). Next: the combat AI follow-up (B1 losing fights, MONSTER TACTICS ORIGINAL / SMARTER / SMARTEST, B1-B3 regression fights). P16 still waits on Jeremy's tests.

## Requests to another lane

Format: `date · from → to · what · status (open / taken / done)`

- 2026-11-14 · design → main · Hand play for stuck areas (decided, Methods 2; replaces this morning's closed rule): bot run, then two directed attempts; if they add < 1 point, play the area by hand in the lab (~1 hour), like a player, to find out what's happening; if still unclear, a save plus a test request for Jeremy in the Test List doc; then close with reasons. Leave a key list or plan that replays the hand play exactly; hand-play coverage to its own file, then merged; general findings go back into the bot. **First case: 2:20's 34 plain jobs that replay to 0x9DDE instead of 0x9D7E** (the dice job's forced die at 0x9B8A suspected). · open
- 2026-11-14 · design → main · Differential checks (decided, Methods 2; plan in ideas/game-modernizer.md): before chat 20 ends, check that `statediff.sh` still runs on the current save format, and whether the five first events (3:8 clerk's reward, 6:19 silver bottle, 4:2 chest and seal, 2:9 gate payment, 5:7 finale) are reachable from lab saves. The milestone itself starts when coverage closes. · open
- 2026-11-14 · design → side · P21 feature explanations (decided, Methods 2): SETTINGS shows one or two lines of help for the highlighted item (bottom row, original's style); ABOUT on the start menu becomes a menu: FEATURES (per feature: what it does, key, default, difference from the original), CREDITS (today's ABOUT text and the Godot license), room for more. All text from one content file. Mockup to Jeremy first. · done (side chat 5): mockup approved (ABOUT lined up under GOLD's G); built, `content/features.json` + `scripts/ui/feature_text.gd`; Test List section added.
- 2026-11-14 · design → side · Combat AI follow-up (decided, Methods 2): staged losing fights for B1's retreat rule before Jeremy tests it; MONSTER TACTICS becomes ORIGINAL / SMARTER / SMARTEST (Fireball-first openings only at SMARTEST); fixed-seed regression fights for each of B1-B3; Test List entries for each. After P16 unless you see a reason to do it sooner. · open
- 2026-11-14 · design → main · Re-take the reference-check baseline (`refcheck.sh`, `data/refcheck_base.txt`) on current main, noted as the first after A1; say whether chat 18's baseline came before or after A1 landed. · done (chat 19): `data/refcheck_base.txt` is now 3:11 83/77, 5:5 91/88 (chat 19's bot on main with A1; old file kept as `refcheck_base_c18.txt`). Chat 18's baseline (72/64, 91/87) came before A1: it was taken with the code before chat 18's walker, and A1 landed later that day in side chat 3. Chat 18's own walker had measured 3:11 at 87/83; with A1 and today's changes it gives 83/77.
- 2026-11-14 · design → main · Move the side lane's lab keys (`_replay_keys`: `fightend`, `partyhp`, `memorize=`, `order=`, `smartquick`, `smartmonsters`) out of `main.gd` into a side-owned hook file · done (chat 19): `scripts/combat/lab_hooks.gd` (`LabHooks.handles`/`handle`, its `.uid` with it); `main.gd` keeps one branch calling it. Same keys, same behaviour (checked with a `--keys` replay). New side-lane lab keys go there.
- 2026-11-14 · design → main · `tools/lab/README.md`: a one-page "Current method" section at the top; the "Chat N additions" stay below as history. Draft ready: ai-business-ideas `plans/lab-current-method-draft.md` (fill the [check] lines, paste, delete the draft). · done (chat 19): pasted with the [check] lines filled (PC setup, fixed-fps, lanes) and chat 19's additions; the draft file deleted.
- 2026-11-14 · design → main · CLAUDE.md "Ending a chat": the dated entry now goes at the top of ai-business-ideas `plans/chat-log.md`, not `ideas/game-modernizer.md`. · done (chat 19).
- 2026-11-14 · design → main · Load test: does a coverage run's diverged count rise with load? · done (chat 19): it did; fixed with `--fixed-fps 1000` in bot.sh and every generator drawn from the run seed. 2:15 -all after the fix: alone x3 and at P=10, all 13 runs the same walk line for line (111 jobs, 17 diverged, all of them reroll jobs: new dice by design); P=12 the same. At P=10: 7.5 GB of 16 GB still free at the lowest (about 0.8 GB a run), swap 0 MB used, no paging, CPU up to 88%; 154 s a run against 84 s alone. Details: tools/lab/README.md ("Current method", "Chat 19 additions").

## Rule changes

Any push that changes game behaviour (rules, dice, fight outcomes), not just the display, adds a line here in the same
push: what changed and what it may affect. Other lanes re-take their baselines (the reference check first).
Format: `date · lane (chat) · change · may affect`

- 2026-11-14 · side (chat 3) · A1: the original's turn order and spell choice in all fights; CONTINUE BATTLE when every enemy is down but not dead; worthless monster items on a d10 of 1-3 · the bot's real fights, flee jobs, story run, refcheck baseline

## Findings for everyone

- 2026-11-14 · side (chat 5) · P21: every QoL feature now has an entry in `content/features.json` (SETTINGS help, its FEATURES page; credits text moved there too). A lane that adds a feature or a setting adds its entry there (or asks side); a new setting also needs a line in `StartMenu.setting_value` / `change_setting`. `tools/lab/menu_run.sh <keys.py steps>` drives our start menu on a virtual display. Display only, no rule changes.
- 2026-11-14 · main (chat 19) · How many runs in parallel the PC takes (measured with 2:15 -all): P=10 gives 3.9 runs a minute at up to 88% CPU, P=12 only 4.1 at 100%; memory is never the limit (no swap at P=12, 6 GB still free). So: 8 lanes while Jeremy uses the PC (4 threads left for him), 10 when it is idle; 12 gains about 5% and leaves nothing.
- 2026-11-14 · side (chat 4) · P16 is display only: no rule changes, and `main.gd` / `ecl_vm.gd` were not touched this chat, so the lab-key move into a side hook file can go ahead any time. Combat display pacing is off in headless, --play, --keys and --fast runs (`--anim` turns it on).
- 2026-11-14 · main (chat 19) · Shared core touched (small): main.gd has `dev_rng` and `_dev_reseed` (lab only: when a coverage run sets it, the screens' generators are reseeded from it as they open: fight via `CombatScreen.dev_seed`, camp, shop, temple, party menu). No change to play outside the lab. Side lane: a screen that adds a new generator with `randomize()` should get a `_dev_reseed` line after its `open` in main.gd (or tell main), or seed= stops replaying runs that use it.
- 2026-11-14 · main (chat 19) · Lab runs are now about 4x faster (`--fixed-fps`): a coverage `-all` takes 1-4 minutes.
- 2026-11-14 · design · Decided (Methods 2): a QoL feature may change a screen, in the original's own style (font, colours, frame, menu wording and keys; new items after the original ones), with a mockup for Jeremy first; with the feature off in SETTINGS the screen is exactly the original's. Replaces the 2026-11-12 "every screen matches" rule.
- 2026-11-14 · design · ai-business-ideas reorganized: chat logs now in `plans/chat-log.md` (newest first; add your end-of-chat entry at the top); `ideas/game-modernizer.md` keeps decisions and a short Next step. New team rules (Methods 2, dated entry): side-lane hook file, the Rule changes section above, and when an area and M6 coverage close.
- 2026-11-14 · side (chat 3) · Shared core touched today, all small: main.gd's `_replay_keys` lab keys `fightend`, `partyhp`, `memorize=`, `order=`, `smartquick`, `smartmonsters`, and `Spoils.gather`'s new 4th argument in `_after_fight` (ECL 0x6DE3). No ecl_vm.gd changes.
- 2026-11-14 · side (chat 3) · A1 (decided): every fight now uses the original's turn order and spell choice, so the bot's real fights can play out differently. A fight with every enemy down but not dead now plays out the round and asks CONTINUE BATTLE (the bot answers N); shortcut wins set `Combat.decided`. Worthless monster items reach the pile only on a d10 of 1-3.

- 2026-11-14 · main (chat 18) · Variants of one area share `cov_<area>.json`; keep them in one lane, or the last to save wins.
- 2026-11-14 · main (chat 18) · The ECL16.DAX errors were the bot's travel graph, not the engine; covsum.sh now prints SCRIPT ERROR counts. Any SCRIPT ERROR goes here.
- 2026-11-14 · design · Godot `.uid` files: one commit adds them all (done: 4b930c6). After it, commit a new script's `.uid` with the script.

## For the Test List

Items for Jeremy's "Gold Box Reforged – Test List" (Jeremy moves them). Newest first.

- 2026-11-14 · main (chat 19) · DOSBox, 6:25 (the west band's cave): enter the cave until it puts you at its west
  entrance (0,2) or east entrance (15,3); can the party walk on from there? On our map both squares are walled on
  three sides, and the cave's north half (five set fights) has no way in at all.
- 2026-11-14 · main (chat 19) · DOSBox, 7:23 (inside Yarash's pyramid): at the runes door (12,3, facing east) answer
  a wrong password and YES: the monster's 200 damage kills the party. Does the original carry on to the end of that
  script (0x4A51 bit 64) before the "party is lost" screen? Ours stops at the damage.

