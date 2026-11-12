# Ships tailscaled as an xz blob (~4.4 MB vs 19.8 MB raw) in the read-only
# rootfs; tailscaled-boot expands it into tmpfs on each boot.
#
# The hook is installed into /etc/storage/... only via the storage seed, so
# instead we call it from mtd_storage.sh's func_start_apps(), which runs on
# every boot after the storage partition is mounted (see patch file).

all:
	@:

romfs:
	@if [ ! -f tailscaled ]; then \
		echo "tailscale: no binary staged, skipping"; \
		exit 0; \
	fi
	@mkdir -p $(INSTALLDIR)/usr/sbin
	xz -9 -T0 -c tailscaled > $(INSTALLDIR)/usr/sbin/tailscaled.xz
	chmod 0644 $(INSTALLDIR)/usr/sbin/tailscaled.xz
	$(ROMFSINST) -p +x /usr/sbin/tailscaled-boot
	@ls -l $(INSTALLDIR)/usr/sbin/tailscaled.xz

clean:
