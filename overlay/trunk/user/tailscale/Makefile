# Ships tailscaled + the tailscale CLI as gzip blobs in the read-only rootfs
# and expands them into tmpfs on each boot.
#
# Sizes: tailscaled 19.8 MB -> 6.6 MB, tailscale 24.0 MB -> 8.0 MB. Neither
# fits the 28.5 MB rootfs raw; both fit compressed.
#
# gzip rather than xz because Padavan's busybox has no xz applet.
# The CLI is required: tailscaled has no TS_AUTH_KEY / --auth-key equivalent,
# so joining needs `tailscale up --authkey`.
#
# The boot hook is called from rc.c (see the rc.c overlay), because init never
# runs `mtd_storage.sh load`, so hooks in func_start_apps() never fire.

all:
	@:

romfs:
	@if [ ! -f tailscaled ]; then \
		echo "tailscale: no binaries staged, skipping"; \
		exit 0; \
	fi
	@mkdir -p $(INSTALLDIR)/usr/sbin
	gzip -9 -c tailscaled > $(INSTALLDIR)/usr/sbin/tailscaled.gz
	chmod 0644 $(INSTALLDIR)/usr/sbin/tailscaled.gz
	@if [ -f tailscale ]; then \
		gzip -9 -c tailscale > $(INSTALLDIR)/usr/sbin/tailscale.gz; \
		chmod 0644 $(INSTALLDIR)/usr/sbin/tailscale.gz; \
	else \
		echo "tailscale: CLI not staged, daemon only"; \
	fi
	$(ROMFSINST) -p +x /usr/sbin/tailscaled-boot
	$(ROMFSINST) -p +x /usr/sbin/tailscale-init
	@ls -l $(INSTALLDIR)/usr/sbin/ | grep -E "tailscal"

clean:
