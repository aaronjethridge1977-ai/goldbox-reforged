#!/bin/bash
# Rebuild ~/lab from the git-ignored .lab folder (see README), using the scripts from the
# persistent source tree .lab/tree (kept in step with the repo by patches; apply.sh).
set -e
P=$HOME/mnt/goldbox-reforged; L=$HOME/lab
mkdir -p $L/cap $L/godot $L/root
cd $L
[ -d dosbox-staging-linux-x86_64-0.83.0-7b400 ] || tar xJf $P/.lab/dosbox-staging-linux-x86_64-v0.83.0.tar.xz
[ -d root/POOLRAD ] || cp -r "$P/Pool of Radiance/POOLRAD" root/POOLRAD
cp $P/.lab/tree/tools/lab/* $L/
cp $P/.lab/font.json $P/.lab/wheel.json $L/
sed -i "s#LAB#$L#g" $L/por.conf
ln -sfn root/POOLRAD $L/game
[ -x godot/Godot_v4.7.2-stable_linux.x86_64 ] || (cd godot && python3 -c "import zipfile;zipfile.ZipFile('$P/.lab/Godot_v4.7.2-stable_linux.x86_64.zip').extractall('.')" && chmod +x Godot_v4.7.2-stable_linux.x86_64)
[ -f $P/saves/quicksave.cfg ] && cp $P/saves/quicksave.cfg $L/
ls $L
