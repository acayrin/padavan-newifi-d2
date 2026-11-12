# Ships tailscaled as a gzip blob (~6.2 MB vs 19.8 MB raw) in the read-only
# rootfs; tailscaled-boot expands it into tmpfs on each boot.
#
# gzip is used rather than xz because Padavan's busybox has no xz/unxz applet,
# only gzip/zcat/bzcat.
#
# The boot hook lives in mtd_storage.sh func_start_apps(), which runs on every
# boot after the storage partition is mounted.

all:
	@:

romfs:
	@if [ ! -f tailscaled ]; then \
		echo "tailscale: no binary staged, skipping"; \
		exit 0; \
	fi
	@mkdir -p $(INSTALLDIR)/usr/sbin
	gzip -9 -c tailscaled > $(INSTALLDIR)/usr/sbin/tailscaled.gz
	chmod 0644 $(INSTALLDIR)/usr/sbin/tailscaled.gz
	$(ROMFSINST) -p +x /usr/sbin/tailscaled-boot
	@ls -l $(INSTALLDIR)/usr/sbin/tailscaled.gz

clean:
