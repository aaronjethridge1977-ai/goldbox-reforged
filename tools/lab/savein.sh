#!/bin/bash
# savein.sh <fixture>: copies a fight's start save from combat5/saves/<fixture>/ (lab only; game
# data, never committed) into game/ as save A, the scratch slot (Combat Chat 5: the late fights).
cd "$(dirname "$0")"
cp combat5/saves/$1/* game/
