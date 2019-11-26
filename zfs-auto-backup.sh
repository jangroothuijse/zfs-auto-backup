#!/bin/bash

# Goal: send snapshots to other disks or remote hosts, to backup the snapshots.
# on local disks it only depends on zfs tools, on remote systems it depends on
# ssh (and login using public/private keys), rsync and zfs tools.

# in order to install this script in cron, please use lockFile (from daemontools
# package).

# Parse arguments
# Source dir for snapshots
SRC=$1
# Where to copy the snapshots to
DST=$2
# Label of the snapshots
TYPE=$3
# Host of the backup
HOST=$4

ssh='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

# Check that DST is available, exit without errors if it is not.
if [ ! "$HOST" = "localhost" ]
	then # if it is up, check that the DST exists
		if ! $ssh -q "$HOST" exit;
			then # Assume host is down, or back disk not mounted.
				exit
		fi
fi

# for each source snapshot, ordered by age ASC.
for snap in $(zfs list -t snapshot | awk '{print $1}' | grep "${SRC}@zfs-auto-snap_${TYPE}"| sort); do
	echo "Backing up $snap"
	base=$(basename "$snap")

	# If snapshot already exists in DST then skip the backup, but save the name
	# so we might diff against it in upcoming snapshots.
	if [ ! "$HOST" = "localhost" ]
		then # For remote backups use ssh to see if the snapshot already exists.
			if $ssh "$HOST" stat "$DST" \> /dev/null 2\>\&1
				then # file exists in backup already
					echo "File exists in backup, using for reference: $snap"
					prev=$snap # update prev, it may be used to diff.
					continue
			fi
		else # On local backups we can just check if the file exists.
			if [ -e "$DST" ]
				then # The file exists in backup already
				echo "Snapshot $base already exists in dst $DST"
				prev=$snap # Update prev, it may be used to diff.
				continue
			fi
	fi

	# If this was the first (oldest) snapshot, then send the whole thing.
	# We test is if it was the oldest, by checkig if prev is empty:
	if [ -z "$prev" ]
		then # Prev was empty, so this is the first, so create a full backup.
			if [ ! "$HOST" = "localhost" ]
				then # Remote full backup, send everything over ssh directly.
					echo "Sending full snapshot $snap through ssh directly"
					zfs send "$snap" | $ssh "$HOST" zfs receive "$DST"
				else # Local full backup, pipe diff to DST fs.
					echo "Sending full snapshot $snap through pipe"
					zfs send "$snap" | zfs receive "$DST"
			fi
		else # Only send the diff between snap and prev, an incremental backup.
			if [ "$HOST" != "localhost" ]
				then # Remote incremental backup, rync the diff.
					backup="delta_$base"
					echo "Sending incremental from $prev to $snap using rsync"
					zfs send -i "$prev" "$snap" > /tmp/"$backup" 
					echo "rsync -partial /tmp/$backup $HOST:/tmp/$backup"
					rsync -partial /tmp/"$backup" "$HOST":/tmp/"$backup"
					$ssh "$HOST" zfs receive "$DST" < /tmp/"$backup"
					$ssh "$HOST" rm -rf /tmp/"$backup"
					rm -rf /tmp/"$backup"
				else # Local incremental backup
					echo "Sending incremental from $prev to $snap through pipe"
					zfs send -i "$prev" "$snap" | zfs receive "$DST"
			fi
	fi
	# update prev, it may be used to diff.
	prev=$snap
done;

