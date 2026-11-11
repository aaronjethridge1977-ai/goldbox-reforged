#!/bin/bash
# Apply a gzip+base64 patch (stdin) from the cloud workspace to .lab/tree; arg 1 = expected md5.
# (.lab/tree sits inside the repo folder, so plain patch, not git apply.)
P=$HOME/mnt/goldbox-reforged
base64 -d | gunzip > /tmp/in.patch || exit 1
echo "md5 $(md5sum < /tmp/in.patch | cut -c1-32) expected $1"
cd $P/.lab/tree && patch -p1 --forward --no-backup-if-mismatch < /tmp/in.patch && echo applied
