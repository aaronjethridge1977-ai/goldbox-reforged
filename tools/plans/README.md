# Plan files: the shared format

A plan is what a player does, line by line, from a party's creation (or a checkpoint) on. Two players read the
same files: main's bot (`scripts/dev/bot.gd`, our engine, headless) and the Player lane (the original in DOSBox,
`tools/original_player/`). Both follow ai-business-ideas `plans/play-guide.md` for the player's habits (the inn,
not the streets; rest until whole; ...). Keep plans readable by a person: one action a line, a comment above anything
that isn't obvious, the source of each square or answer (the Clue Book, an area's script, the lab).

The Player lane adds fields it needs by a request on the board (`docs/board.md`), and they are added here first:
the bot logs any line it doesn't know as an issue ("unknown plan command") and goes on.

## The play guide and the bot (chat 27)

Each of the guide's general rules, and where main's bot keeps it (`scripts/dev/bot.gd`) or where it doesn't:

| Guide rule | The bot |
|---|---|
| 1 No resurrection; a death is a reload | A member dead, stoned or gone in a full run reloads the last `checkpoint` (counted "deaths"); temples raise only on `temple x,y raise`; `explore` never checkpoints with a member dead. |
| 2 The inn, not the streets; GO to the watch | `rest 3:0 inn` and the other `rest <area> inn` lines; `answer 3:0 ROUSTED BY THE CITY WATCH\|GO`; before the doors open at 14:00 it waits at the inn, not in the street (`_wait_for_day`). |
| 3 Coin for the inn, platinum included | Reactive: on "ENOUGH PLATINUM" the richest member buys arrows for change and the inn is tried again. Training is skipped while the purse is short of 1000 gold. |
| 4 Rest at the inn until whole and memorized | The inn rests, cures with Cure Light Wounds and rests again until everyone is whole (up to 12 rounds; a day a hit point without a cleric). |
| 5 Leave where rests are interrupted | An interrupted camp rest walks to the inn when town is near (`_rest_at_inn`); the caves rest outside (`rest 8:13 inn 4A8D 1`). |
| 6 Train as soon as due | `_can_train` sends it to town when anyone has the experience and the purse holds 1000 gold. |
| 7 Heal and memorize before a story fight | `_prepare` before each event; in `rest ... inn` areas cures first, the inn only when worn down (under 60% or spells mostly spent). |
| 8 Locks: best thief, then BREAK or KNOCK | Pick, then bash, then Knock (the library's doors). |
| 9 A stalemate: flee and come back | **Not kept**: after 40 rounds with nobody hurt the bot wins by a logged `win` shortcut, listed for the Player lane, which plays these fights in the original (its queue item 2). |
| 10 Don't raise an area's alarm | Plan answers (Bane's altar's box and crosse left; Valjevo by clean tries at a way out). |

## Files

- `playthrough.plan`: the whole game, a new party to Tyranthraxus (the full run). Standing rules first (rest,
  expect_level, answer, fight, parley, gate, exit, warp, hire), then the story in the Clue Book's order, with a
  `checkpoint` after each step worth coming back to.
- `cover_<set>-<block>[-variant].plan`: a coverage run of one area (`start` a checkpoint, `travel`, then `cover`).
  Coverage only; never a playthrough.
- Areas are `<set>:<block>` (ECL file and block: New Phlan is `3:0`); squares are `x,y` on the area's map (0,0 top
  left, north up), directions N E S W.

## Lines

`#` starts a comment; blank lines are skipped. Words are separated by spaces; `|` separates a shop's purchases and
an answer's question from its choice.

**Party**
- `char <race> <class> <alignment> <name>`: roll a character (rerolled until its class's main abilities are 15+).
- `modify`: MODIFY CHARACTER as a player would (abilities and HP to the most race and class allow).
- `begin`: BEGIN ADVENTURING.
- `hire <n>`: how many hired NPCs to take on when the arena offers them.
- `ready`: ready the best gear.

**Moving**
- `tour x,y ...`: walk to each square in turn, playing whatever happens on the way.
- `face N|E|S|W`, `step`, `key <name>`, `say <text>` (typed at a prompt), `answers a;b;c` (the next menus' choices).
- `travel <set>:<block>`: walk area to area by the area graph.
- `exit <from area> x,y <dir> <to area> [wall]`: a way out the area graph can't name; `wall` when the map draws a
  wall there (a secret door the script opens).
- `warp <area> x,y x,y`: a square that moves the party elsewhere in the same area.
- `gate <from area> x,y <to area> <choice>`: a way between areas that a menu opens. A gate may start with
  `[XXXX&M=V]`: it holds only while ECL byte XXXX AND M is V.
- `search on|off`: SEARCH mode (10-minute steps).

**Events**
- `answer <area> <words of the question>|<choice>` (standing): answer that question so wherever it comes;
  `[XXXX&M=V]` as for gates.
- `fight <area> <words of the encounter's text>` (standing): COMBAT there, even where the odds say flee.
- `parley <area> <words of the encounter's text>` (standing): PARLAY there.
- `explore [events]`: visit every event of the area, resting first; the listed events wait for training.
- `revisit <event> <times>`: step onto that event again and again (the library's stacks).
- `clerk`: City Hall twice (rewards, then commissions).

**Resting and town**
- `rest <area> inn|camp [<hex addr> <value>]` (standing): where to rest in an area (the inn until script memory
  addr reaches value).
- `heal`, `memorize`, `restuntil <hour>`, `campday <n>`, `grind <hex addr> <n>`, `level <n>`.
- `mopup` (chat 28, Jeremy's Q1: honest experience): back to every area whose events `explore` left for later
  (judged unwinnable then; not the plan's own skips), training first, taking on those it now judges winnable;
  the list rides in the checkpoints' counters.
- `town`: New Phlan's round (rewards, temple, training, inn). `inn x,y`, `shop x,y | <member> <item> | ...`,
  `sell x,y`, `trainat x,y`, `train`, `buy <member> <item>`.
- `temple x,y [raise]`: cures at a temple. **Raise Dead only with `raise`**, in a test of the mechanic: a playthrough
  never depends on resurrection (Jeremy, Methods 4).
- `expect_level <area> <n>` (standing): the level the game expects of a party there.

**Run control**
- `checkpoint <name>`: save. **A wipe, or in a full run any member's death, goes back to the last checkpoint**
  (chat 26; up to 8 tries, the first with the party restored by a logged shortcut).
- `start <checkpoint name>` (with `--checkpoints=<folder>`), `rules <plan file>` (another plan's standing rules),
  `expect <area>`, `status`, `log <text>`, `stop`.

**Lab only (never in a playthrough except as a logged shortcut the run report lists)**
- `cover <area> <minutes> [all] [full] [states=<n>] [seed=<hex>] [only=<events>]`: a coverage run.
- `shortcut restore | level ... | win [<n> at x,y | at ev<k>] | keep <n> | flag <addr> or <v> <why> |
  item <type> <name> | npc <id> <morale> <why> | teleport ...`.
