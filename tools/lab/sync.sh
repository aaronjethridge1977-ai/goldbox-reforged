#!/bin/bash
# Unpack the latest source sent from the cloud workspace (.lab/src_now.tgz) into ~/lab/src
# and run the Godot check on it.
cd "$(dirname "$0")"
rm -rf src && mkdir src && tar xzf "$HOME/mnt/goldbox-reforged/.lab/src_now.tgz" -C src && ./check_godot.sh "$PWD/src"
