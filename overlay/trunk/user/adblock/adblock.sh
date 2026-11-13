#!/bin/sh
# Ad-blocking for every LAN client via dnsmasq, with no per-device setup.
#
# Blocked names resolve to 0.0.0.0 (and :: for IPv6) rather than NXDOMAIN or
# REFUSED. Null answers are deliberate: many apps treat a failed lookup as
# "retry forever" or break their error handling, whereas 0.0.0.0 fails to
# connect and they fall through quickly.
#
# Lists live in tmpfs (/tmp/adblock) so the flash is not rewritten daily; they
# are re-downloaded at boot and once a day by cron.
#
# dnsmasq is pointed at the directory, not the file: --addn-hosts accepts a
# directory and reads every file inside it, so the user's own
# /etc/storage/dnsmasq/hosts keeps working untouched.

DIR=/tmp/adblock
HOSTS="$DIR/hosts"
LOG=/tmp/adblock.log

# Upstream lists. Kept small on purpose - a 4 MB /var tmpfs and 128 MB RAM
# mean a multi-million-entry list would be counterproductive.
LISTS="
https://adaway.org/hosts.txt
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt
"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"; }

fetch_all()
{
	mkdir -p "$DIR"
	: >"$DIR/raw.tmp"

	local url
	for url in $LISTS; do
		# -q quiet, follow redirects, short timeouts so boot is not delayed
		if wget -q -T20 -O "$DIR/part.tmp" "$url" 2>/dev/null; then
			cat "$DIR/part.tmp" >>"$DIR/raw.tmp"
			log "fetched $url"
		else
			log "FAILED $url"
		fi
	done
	rm -f "$DIR/part.tmp"
}

build()
{
	# Parse hosts-format lists only: "<ip> <name>". Anything else is ignored,
	# so a truncated or HTML error page cannot poison the list.
	#
	# Output is deduplicated and sorted; dnsmasq re-reads hosts files on SIGHUP
	# so a stable file avoids needless reload churn.
	# Strict validation: only accept a bare hostname as the second field.
	# Some lists are not hosts format at all (ABP rules, adblock syntax,
	# decorative "#" / quoted strings) and would otherwise inject garbage
	# entries like an entry literally named '#', which dnsmasq rejects or
	# silently ignores.
	awk '
		/^[[:space:]]*#/ { next }
		NF >= 2 {
			ip = $1
			if (ip != "0.0.0.0" && ip != "127.0.0.1" && ip != "::" && ip != "::1") next
			d = $2
			# must look like a DNS name: labels of alnum/underscore/hyphen,
			# at least one dot, no wildcards, no quotes, no punctuation
			if (d !~ /^[A-Za-z0-9_]([A-Za-z0-9_-]*[A-Za-z0-9_])?(\.[A-Za-z0-9_]([A-Za-z0-9_-]*[A-Za-z0-9_])?)+$/) next
			if (d == "localhost" || d == "localhost.localdomain") next
			if (d ~ /^[0-9.]+$/) next
			seen[d] = 1
		}
		END {
			for (d in seen) {
				print "0.0.0.0 " d
				print ":: " d
			}
		}
	' "$DIR/raw.tmp" | sort -u >"$HOSTS.new"

	# Atomic swap so dnsmasq never reads a half-written file.
	mv -f "$HOSTS.new" "$HOSTS"
	log "built $HOSTS with $(wc -l <"$HOSTS") entries"
}

reload_dnsmasq()
{
	[ -f "$HOSTS" ] || return 0
	# SIGHUP makes dnsmasq re-read hosts files without dropping the cache or
	# interrupting DHCP.
	local pid=$(cat /var/run/dnsmasq.pid 2>/dev/null)
	[ -n "$pid" ] && kill -HUP "$pid" 2>/dev/null
}

case "$1" in
	start|update)
		[ "$(nvram get adblock_enable)" = "1" ] || { log "disabled"; exit 0; }
		fetch_all
		build
		reload_dnsmasq
		;;
	stop)
		rm -f "$HOSTS"
		reload_dnsmasq
		log "disabled, list removed"
		;;
	status)
		if [ -f "$HOSTS" ]; then
			echo "enabled, $(wc -l <"$HOSTS") entries"
		else
			echo "disabled"
		fi
		;;
	*)
		echo "Usage: $0 {start|stop|update|status}"
		exit 1
		;;
esac
