# Padavan build for D-Team Newifi D2 (NEWIFI-D2)

Overlay repo: the workflow clones `OpenPadavan/padavan` and applies these files.

- English-only UI (no Chinese dictionary)
- custom web UI background (argon `bg1.webp`, fixed cover)
- `trunk/user/tailscale` installs a **prebuilt** `tailscaled` to `/usr/sbin`
- OpenVPN / Transmission / miniDLNA disabled to leave room for tailscaled

## Build

Actions -> `build-newifi-d2` -> Run workflow:

- `tailscale_url`: direct link to your `tailscaled` (mipsle, static). Leave empty to build without it.
- `tailscale_sha256`: optional integrity check.

Output: `newifi-d2-padavan` artifact containing the `.trx`, flashable via Breed.

Padavan's default LAN address and admin/admin login apply after boot.
