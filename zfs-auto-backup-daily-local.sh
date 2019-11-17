#!/bin/bash

# Goal: send snapshots to other disks or remote hosts, to backup the snapshots.
# on local disks it only depends on zfs tools, on remote systems it depends on
# ssh (and login using public/private keys), rsync and zfs tools.

# in order to install this script in cron, please use lockFile (from daemontools
# package).
DST=backup

# for each source snapshot, ordered by age ASC.
for snap in $(zfs list -t snapshot | awk '{print $1}' | grep "@zfs-auto-snap_daily" | grep -v "backup/"  | sort); do
	echo "Backing up $snap"
	base=${snap:0: -15}
	prevbase=${prev:0: -15}

	# If snapshot already exists in DST then skip the backup, but save the name
	# so we might diff against it in upcoming snapshots.
	if [ -e "$DST" ]
		then # The file exists in backup already
		echo "Snapshot $snap already exists in dst $DST"
		prev=$snap # Update prev, it may be used to diff.
		continue
	fi

	# If this was the first (oldest) snapshot, then send the whole thing.
	# We test is if it was the oldest, by checkig if prev is empty:
	if [ -z "$prev"w ] && [ "$base" == "$prevbase" ]
		then # Prev was empty, so this is the first, so create a full backup.
			# Local full backup, pipe diff to DST fs.
			echo "Sending full snapshot $snap through pipe"
			zfs send "$snap" | zfs receive "$DST"
		else # Only send the diff between snap and prev, an incremental backup.
			
			# Local incremental backup
			echo "Sending incremental from $prev to $snap through pipe"
			zfs send -i "$prev" "$snap" | zfs receive "$DST"
			
	fi
	# update prev, it may be used to diff.
	prev=$snap
done;

