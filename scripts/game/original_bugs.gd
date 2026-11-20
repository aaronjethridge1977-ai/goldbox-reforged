class_name OriginalBugs
extends RefCounted
## SETTINGS: ORIGINAL'S BUGS (Jeremy, 2026-11-20 07:40, through the Lead). Off by default: ours plays with
## the original's bugs fixed. On: as the original. Every lab run has it on (a `--keys=` replay, the original's
## dice `tpseed=`, or GBR_ORIGINAL_BUGS=1), so the differential checks, regress and the Stage 1 match keep
## comparing with the original. The bugs are listed in docs/original-bugs.md; each fix goes at its bug's site
## as `if not OriginalBugs.on(): <the fix>`. (Main chat 70: the switch only; no fix has landed yet.)

const KEY := "original_bugs"

## For the FEATURES page and SETTINGS (Combat's screens): docs/original-bugs.md's rows, in short.
const LIST := [
	"MAGIC MISSILE AT LEVEL 1 DOES NOTHING",
	"SPELL: THE FIRST MEMBER CASTS KNOCK",
	"CLOCK ADDS AN UNSET COUNT",
	"PARTY CHECK WRITES A STACK BYTE",
	"A SPOILED SPELL LEAVES THE ATTACKER'S MEMORY",
	"THE WILDERNESS FIELD'S UNSET TERRAIN",
	"MAGIC RESISTANCE WRAPS",
	"DOUBLE LEVEL DRAIN",
	"SHARE WITH AN OVERLOADED MEMBER",
	"THE CACHED LOAD GOES STALE",
	"PARTY STRENGTH WRAPS",
	"CHARISMA BELOW 3 PARLEY BONUS",
	"PROTECTION FROM EVIL'S TO-HIT",
	"MIRROR IMAGE DOESN'T STOP BLOWS",
]

static var _setting := -1     # -1: not read yet


## Whether the original's bugs are played: always in a lab run, else the SETTINGS switch.
static func on() -> bool:
	if lab_run():
		return true
	if _setting < 0:
		var cf := ConfigFile.new()
		_setting = 1 if cf.load(GameData.SETTINGS_PATH) == OK and bool(cf.get_value("qol", KEY, false)) else 0
	return _setting == 1


## A run the lab drives: the checks compare with the original, bugs and all.
## GBR_ORIGINAL_BUGS=0 (main chat 74): a RECORD MY GAME replay plays the session's own switch (its settings.cfg),
## not the lab's: a session played with the fixes would part at the first fixed bug.
static func lab_run() -> bool:
	if OS.get_environment("GBR_ORIGINAL_BUGS") == "0":
		return false
	if TpDice.on or OS.get_environment("GBR_ORIGINAL_BUGS") == "1":
		return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--keys="):
			return true
	return false


static func save(value: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(GameData.SETTINGS_PATH)
	cf.set_value("qol", KEY, value)
	cf.save(GameData.SETTINGS_PATH)
	_setting = 1 if value else 0
