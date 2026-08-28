# Shared LUKS2 plumbing. The actual `boot.initrd.luks.devices.<name>` entry is
# host-specific (device path, optional detached header, optional FIDO2) and is
# declared in each host's disko.nix - this module only turns on the systemd
# stage-1 initrd, which is required for FIDO2 unlock to work at all.
#
# FIDO2 YubiKey enrollment (replaces the `systemd-cryptenroll --fido2-device=auto`
# call in the old install.sh) is a one-time manual step done after install, since
# it needs the physical key present:
#   sudo systemd-cryptenroll --fido2-device=auto --fido2-with-client-pin=false \
#       --wipe-slot=password /dev/disk/by-partlabel/disk-main-primary
# disko names GPT partition labels "disk-<diskName>-<partitionName>", not just
# the bare partition name - confirmed on real hardware, since disko.nix's disk
# is named "main" and its partition "primary", the label is "disk-main-primary".
# Afterwards add "fido2-device=auto" to that host's crypttabExtraOpts.
#
# Run directly like this (sudo, no chroot) on an already-booted real system,
# it'll prompt interactively for the existing disk passphrase and, if the key
# has one set, its FIDO2 PIN. bootstrap.sh runs the same command inside a
# nixos-enter chroot instead, where neither prompt can reach a terminal (no
# systemd instance in there to service the ask-password request) - see its
# own comments for why it reads both upfront and passes them via $PASSWORD/
# $PIN, which systemd-cryptenroll accepts as non-interactive overrides.
{ ... }:
{
  boot.initrd.systemd.enable = true;
}
