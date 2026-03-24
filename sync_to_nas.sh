#!/bin/bash

SOURCE="/var/lib/Mvideos/"
DEST="/mnt/path/"

# 1. Check if the NAS is actually mounted
if ! mountpoint -q "/mnt/nas"; then
    echo "NAS not mounted. Skipping."
    exit 1
fi

# 2. Check if there are actually any files to sync
# This looks for any files deeper than the date folders
if [ -z "$(find "$SOURCE" -mindepth 2 -type f)" ]; then
    echo "No new merged videos found in $SOURCE. Nothing to do."
    exit 0
fi

# 3. If files found, proceed with the sync
echo "New files detected. Syncing to NAS..."

rsync -rtv --no-perms --no-owner --no-t --no-group --ignore-existing "$SOURCE" "$DEST"

echo "Sync complete."