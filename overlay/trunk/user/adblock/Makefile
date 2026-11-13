# Ad-blocking for all LAN clients via dnsmasq.
#
# The list is fetched into tmpfs by cron (daily) and at boot, and resolved to
# 0.0.0.0 / :: by dnsmasq's addn-hosts. Nothing large is stored on flash.

all:
	@:

romfs:
	$(ROMFSINST) -p +x /usr/sbin/adblock.sh
	$(ROMFSINST) -p +x /usr/sbin/adblock-cron.sh

clean:
