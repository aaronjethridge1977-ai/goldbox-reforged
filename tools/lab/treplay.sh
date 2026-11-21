#!/bin/bash
# treplay.sh <patched checkout> <replay_recording.py out dir> <.gbrrec> <work dir> [audio driver] [extra waits]
# (main chat 93): a RECORD MY GAME session played windowed (DISPLAY, default :95) and paced (--anim), its keys at their
# recorded times (main.gd's timed= item, main chat 93); log in <work>/ours.log. <patched checkout>: a checkout with
# timed= (from chat 93 on; for an older build's commit, ~/gbr/lab/data/c93/timed.py <checkout> adds it).
# REL=<release binary beside its .pck> runs that instead of the editor binary on <work>/proj (a release template
# plays what Jeremy's build does: no bounds checks; chat 93's crash only showed there). Audio: ALSA (to the null
# device through an .asoundrc in <work>/alsa: no sound out loud), PulseAudio (out loud through WSLg) or Dummy.
set -u
SRC=$1; R=$(cd "$2" && pwd); REC=$(realpath "$3"); W=$4; AUD=${5:-ALSA}; NW=${6:-120}
G=/home/aaron/gbr/checks/bin/godot
python3 -c "import shutil,os,sys; p=sys.argv[1]; shutil.rmtree(p) if os.path.exists(p) else None" "$W"
mkdir -p "$W/proj/tools"
cp -r "$SRC/project.godot" "$SRC/icon.svg" "$SRC/scenes" "$SRC/scripts" "$W/proj/"
[ -d "$SRC/content" ] && cp -r "$SRC/content" "$W/proj/"
cp "$SRC"/tools/*.gd "$W/proj/tools/" 2>/dev/null
(cd "$W/proj" && XDG_DATA_HOME=$W/xdg timeout 120 "$G" --headless --path . --import >/dev/null 2>&1)
cp -r /home/aaron/gbr/checks/data/game "$W/game"
cp "$R"/start/* "$W/game/"
mkdir -p "$W/xdg/godot/app_userdata/Gold Box Reforged"
cp "$R/settings.cfg" "$W/xdg/godot/app_userdata/Gold Box Reforged/settings.cfg"
cp /home/aaron/gbr/checks/data/134/ours.cfg "$W/ours.cfg"
PRE=$(cut -d, -f1-3 "$R/keys")
KEYS="$PRE,timed=$REC$(printf ',wait%.0s' $(seq 1 "$NW"))"
cd "$W"
H=$HOME
if [ "$AUD" = ALSA ]; then H=$W/alsa; mkdir -p "$H"; printf 'pcm.!default { type null }\n' > "$H/.asoundrc"; fi
HOME=$H DISPLAY=${DISPLAY_N:-:95} GBR_ORIGINAL_BUGS=0 XDG_DATA_HOME=$W/xdg timeout ${TMO:-900} ${REL:-$G} --audio-driver "$AUD" \
	$([ -z "${REL:-}" ] && echo --path "$W/proj") -- --game-path="$W/game" --save="$W/ours.cfg" --anim "--keys=$KEYS" > "$W/ours.log" 2>&1
echo "exit $?"
tail -5 "$W/ours.log"
