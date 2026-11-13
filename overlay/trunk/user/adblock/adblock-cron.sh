#!/bin/sh
# Install or remove the daily adblock refresh in busybox crond's crontab.
#
# /var is a 4 MB tmpfs and busybox crond reads /var/spool/cron/crontabs/<user>,
# so the entry is written there and rewritten on every boot (it does not
# survive a reboot by design - the image is read-only and /var is RAM).

CRONTAB_DIR=/var/spool/cron/crontabs
CRONTAB="$CRONTAB_DIR/root"
MARK="# adblock-refresh"

if [ "$1" = "remove" ]; then
	grep -v "$MARK" "$CRONTAB" >"$CRONTAB.tmp" 2>/dev/null
	mv -f "$CRONTAB.tmp" "$CRONTAB" 2>/dev/null
	killall -HUP crond 2>/dev/null
	exit 0
fi

mkdir -p "$CRONTAB_DIR"
: >>"$CRONTAB"

grep -q "$MARK" "$CRONTAB" || {
	# Two entries: the nightly refresh, and a mid-morning catch-up. The second
	# matters because at boot the WAN may still be down, in which case the list
	# is empty until something retries. 'update' is cheap when the file is
	# already good - it refetches, but only hourly in practice.
	echo "17 4 * * * /usr/sbin/adblock.sh update $MARK" >>"$CRONTAB"
	echo "43 10 * * * /usr/sbin/adblock.sh update $MARK" >>"$CRONTAB"
}

chmod 600 "$CRONTAB"
killall -HUP crond 2>/dev/null
exit 0
