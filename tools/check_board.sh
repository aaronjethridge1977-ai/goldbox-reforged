#!/bin/bash
# check_board.sh [<repo or worktree>]: a push check every lane runs (Lead, Methods 8; main chat 70): fails (exit 1)
# when docs/board.md is 50 KB (51200 bytes) or more. Archive answered requests to docs/board-archive.md first.
R=${1:-$(cd "$(dirname "$0")/.." && pwd)}
n=$(wc -c < "$R/docs/board.md")
if [ "$n" -ge 51200 ]; then
	echo "BOARD TOO BIG: docs/board.md is $n bytes (limit 51200): move answered requests to docs/board-archive.md"
	exit 1
fi
echo "board OK: docs/board.md $n bytes (limit 51200)"
