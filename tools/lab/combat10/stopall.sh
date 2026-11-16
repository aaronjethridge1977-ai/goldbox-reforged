#!/bin/bash
# stopall.sh: this lab's presser, trace reader and DOSBox stopped (killmine.sh from a script, never inline).
cd /home/aaron/gbr/combat_lab
./killmine.sh presser.py; ./killmine.sh 'trace.py run'; ./killmine.sh '[d]osbox -conf'; sleep 1
