#!/bin/bash
# cmpfight2.sh <save letter> <seed hex> "<keys before the seed>" "<keys after>" [orig|ours|both]
# cmpfight3.sh with one seed (see there).
exec "$(dirname "$0")/cmpfight3.sh" "$@"
