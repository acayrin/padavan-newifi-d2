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

# Default upstream lists, used when nvram adblock_lists is empty. Kept small
# on purpose: the router has limited RAM, and a multi-million-entry list would
# cost more than it saves.
DEFAULT_LISTS="
https://adaway.org/hosts.txt
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt
"

# adblock_lists in nvram overrides the defaults: one URL per line (commas or
# spaces also work). Anything hosts-format is accepted, which is what AdGuard,
# AdAway, StevenBlack and most "adblock hosts" mirrors publish.
get_lists()
{
	# Publish the defaults for the UI placeholder, so the addresses are defined
	# only here rather than duplicated in the page.
	# Comma separated rather than newlines: HTML normalises newlines inside an
	# attribute to spaces, which would run the URLs together in the textarea
	# placeholder. built with tr/awk because busybox has no paste.
	nvram set adblock_defaults="$(echo $DEFAULT_LISTS | tr -s ' \t' '\n' \
		| sed '/^$/d' | awk 'NR>1 {printf ", "} {printf "%s", $0}')"

	local custom
	custom=$(nvram get adblock_lists 2>/dev/null)
	custom=$(echo "$custom" | tr ',;' '\n\n')
	if [ -n "$(echo "$custom" | tr -d ' \t\n')" ]; then
		echo "$custom"
	else
		echo "$DEFAULT_LISTS"
	fi
}

LISTS=""

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"; }

fetch_all()
{
	mkdir -p "$DIR"
	: >"$DIR/raw.tmp"

	local url
	LISTS=$(get_lists)
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

	local n
	n=$(wc -l <"$HOSTS" 2>/dev/null | tr -d ' ')
	log "built $HOSTS with ${n:-0} entries"
	# Surface the count in the UI; tmpfs is wiped on reboot so it is only a
	# display value and needs no commit.
	nvram set adblock_entries="${n:-0} domains blocked"
}

reload_dnsmasq()
{
	# dnsmasq does NOT re-read addn-hosts on SIGHUP in this build: measured by
	# appending a unique domain and sending SIGHUP, after which the name still
	# resolved upstream. It also cannot be replaced by killall alone, because
	# the old process keeps the listening socket and the new one dies with
	# "failed to create listening socket ... Address already in use".
	#
	# So restart it through rc, which tears down and brings the service back in
	# the right order. On a freshly booted box dnsmasq may not be up yet; that
	# is fine, rc will read the new list when it starts.
	if [ ! -f "$HOSTS" ]; then
		# list removed: still needs a restart for the removal to take effect
		[ -z "$(nvram get adblock_enable)" ] || true
	fi

	if [ -x /sbin/rc ]; then
		/sbin/rc restart_dnsmasq >/dev/null 2>&1
	else
		killall -q dnsmasq 2>/dev/null
	fi
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
	defaults)
		# Used to fill the UI placeholder, so the addresses exist in exactly
		# one place (this script) instead of being duplicated in the page.
		get_lists
		;;
	*)
		echo "Usage: $0 {start|stop|update|status|defaults}"
		exit 1
		;;
esac
