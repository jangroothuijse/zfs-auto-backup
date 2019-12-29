install:
	cp zfs-auto-backup-daily-local /usr/sbin/
	chmod +x /usr/sbin/zfs-auto-backup-daily-local
	cp etc/cron.hourly/zfs-auto-backup-daily-local /etc/cron.hourly/zfs-auto-backup-daily-local
	chmod +x /etc/cron.hourly/zfs-auto-backup-daily-local
	cp zfs-auto-backup-daily-remote /usr/sbin/
	chmod +x /usr/sbin/zfs-auto-backup-daily-remote
	cp etc/cron.hourly/zfs-auto-backup-daily-remote /etc/cron.hourly/zfs-auto-backup-daily-remote
	chmod +x /etc/cron.hourly/zfs-auto-backup-daily-remote
