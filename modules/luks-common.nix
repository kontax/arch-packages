# Shared LUKS2 plumbing. The actual `boot.initrd.luks.devices.<name>` entry is
# host-specific (device path, optional detached header, optional FIDO2) and is
# declared in each host's disko.nix - this module only turns on the systemd
# stage-1 initrd, which is required for FIDO2 unlock to work at all.
#
# FIDO2 YubiKey enrollment (replaces the `systemd-cryptenroll --fido2-device=auto`
# call in the old install.sh) is a one-time manual step done after install, since
# it needs the physical key present:
#   sudo systemd-cryptenroll --fido2-device=auto --fido2-with-client-pin=false \
#       --wipe-slot=password /dev/disk/by-partlabel/primary
# Afterwards add "fido2-device=auto" to that host's crypttabExtraOpts.
{ ... }:
{
  boot.initrd.systemd.enable = true;
}
