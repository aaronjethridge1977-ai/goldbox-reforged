class_name PoolRadPortraits
extends RefCounted
## Pool of Radiance content: our tags for the 14 heads and 12 bodies that character creation
## offers (positions in the original's own creation list, 1-based), so a new character can start
## on a fitting portrait (SETTINGS: PORTRAITS MATCHED). Judgement calls from looking at each
## picture, 2026-11-13 (the sheet: lab capture por-portraits.png); no game data here.
##   sex: "M", "F", or "" when the picture could be either.
##   races (heads): the races the face could pass for; only dwarves and gnomes (beards) and the
##     circlet elf stand out at this size.
##   classes (bodies): the classes the clothes or armour suggest.

const HEADS := {
	1: {"sex": "M", "races": ["HUMAN", "HALF-ELF", "ELF"]},      # blond, headband
	2: {"sex": "M", "races": ["HUMAN", "HALF-ELF"]},             # blond, smiling
	3: {"sex": "M", "races": ["HUMAN"]},                         # dark hair, trimmed beard
	4: {"sex": "M", "races": ["DWARF", "GNOME"]},                # white hair, full beard
	5: {"sex": "M", "races": ["GNOME", "DWARF"]},                # bald, white beard
	6: {"sex": "F", "races": ["HUMAN", "HALF-ELF"]},             # dark hair
	7: {"sex": "F", "races": ["HUMAN", "ELF", "HALF-ELF"]},      # long blonde hair
	8: {"sex": "M", "races": ["HUMAN"]},                         # white-haired, older
	9: {"sex": "F", "races": ["HUMAN", "HALF-ELF"]},             # red hair
	10: {"sex": "M", "races": ["HALFLING", "HUMAN"]},            # blond, young
	11: {"sex": "", "races": ["DWARF", "HUMAN"]},                # curly white hair, grim
	12: {"sex": "M", "races": ["DWARF"]},                        # helmet, beard
	13: {"sex": "", "races": ["HALFLING", "HUMAN", "HALF-ELF"]}, # short dark hair, young
	14: {"sex": "F", "races": ["ELF", "HALF-ELF"]},              # circlet
}

const BODIES := {
	1: {"sex": "", "classes": ["FIGHTER", "CLERIC"]},     # plate
	2: {"sex": "M", "classes": ["MAGIC-USER"]},           # purple robe, chain of office
	3: {"sex": "M", "classes": ["FIGHTER"]},              # bare chest
	4: {"sex": "M", "classes": ["CLERIC"]},               # tabard and mace
	5: {"sex": "M", "classes": ["FIGHTER", "CLERIC"]},    # chain mail and cloak
	6: {"sex": "M", "classes": ["THIEF"]},                # shirt and dagger
	7: {"sex": "", "classes": ["FIGHTER"]},               # dark armour, scarf
	8: {"sex": "M", "classes": ["FIGHTER", "THIEF"]},     # leather harness
	9: {"sex": "F", "classes": ["FIGHTER", "THIEF"]},     # silver armour, dagger
	10: {"sex": "", "classes": ["THIEF"]},                # dark robe, dagger
	11: {"sex": "F", "classes": ["FIGHTER"]},             # mail, sword
	12: {"sex": "F", "classes": ["MAGIC-USER"]},          # blue robe, wand
}
