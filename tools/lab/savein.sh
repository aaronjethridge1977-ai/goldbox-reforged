#!/bin/bash
# savein.sh <fixture>: copies a fight's start save from combat5/saves/<fixture>/ or combat6/saves/<fixture>/ (lab only;
# game data, never committed) into game/ as save A, the scratch slot (Combat Chat 5 and 6: the late fights).
cd "$(dirname "$0")"
if [ -d combat6/saves/$1 ]; then cp combat6/saves/$1/* game/; else cp combat5/saves/$1/* game/; fi
