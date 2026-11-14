# Notes for Claude

- **Never commit game data.** No .DAX, .OVR, saves, PDFs or anything from the "Pool of Radiance" folder. `.gitignore` covers these; check `git status` before every commit.
- Engine: **Godot 4.7, GDScript**, Compatibility renderer (web export is a goal).
- Target: **DOS Pool of Radiance**. Reproduce the original faithfully; additions are QoL only (automap, quest tracker, quick save, mouse) unless Jeremy says otherwise.
- Reference projects (ssi-engine, Curse of the Azure Bonds port) are GPL: use them as format documentation only, don't copy code.
- The roadmap and decisions live in the `ai-business-ideas` repo: `plans/game-modernizer-roadmap.md` and `ideas/game-modernizer.md`.
- Jeremy works one step at a time: finish a step, show the result, then move on.
- Use tabs for GDScript indentation; keep files LF.
- Keep content (maps, encounters, text, scripts) separate from the engine: loaded as data, so other Gold Box games and later converted modules are just content packs. Order of work: Pool of Radiance first, then its series, then other Gold Box series, then modules.

## Working as a team (from 2026-11-14)

Several chats work on this repo at once. Jeremy is the designer and decides; the chats build.

- **Lanes and ownership:** `docs/board.md` lists each lane, the chat in it and the files it owns. Change only
  your lane's files. Need a change in another lane's files? Put a request on the board instead.
- **Shared core:** `scripts/main.gd` and `scripts/ecl_vm.gd` belong to the main lane. The side lane may make
  small, contained changes there and says so on the board in the same push.
- **The board:** read `docs/board.md` when you start and after every pull; update it before you push (what
  you're on, requests, findings that matter to other lanes). It replaces Jeremy relaying messages by hand.
- **Before every push:** `git fetch` and rebase onto origin/main; `./check_godot.sh`; after any change to
  `scripts/dev/bot.gd`, `refcheck.sh` (3:11 and 5:5 must not drop); `git status` (no game data, no saves).
- **Godot `.uid` files:** commit a new script's or scene's `.uid` together with it.
- **Ending a chat:** board updated, repos pushed, lab archive saved, a dated entry at the top of ai-business-ideas `plans/chat-log.md`,
  and the next chat's opening post. A chat that ends mid-task leaves the task on the board as open.
- **Questions for Jeremy:** design and priority questions go to him directly; keep them few and ready to answer
  (options and a recommendation). Everything else, decide within your lane and log it.
