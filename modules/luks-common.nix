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
# Deliberately not attempted by bootstrap.sh itself - run this directly
# (sudo, no chroot) on an already-booted real system with the key plugged
# in, and it prompts interactively as needed, both for the existing disk
# passphrase and, if the key has one set, its FIDO2 PIN. Inside a
# nixos-enter chroot (which is where bootstrap.sh runs everything else)
# neither prompt can reach a terminal - no systemd instance in there to
# service the ask-password request - failing with "Failed to query
# password"/"Failed to acquire user PIN: No such file or directory".
# systemd-cryptenroll has no environment-variable override for this despite
# some claims to the contrary online - its actual non-interactive mechanism
# is its own credentials system (cryptenroll.passphrase, cryptenroll.fido2-pin,
# loaded via $CREDENTIALS_DIRECTORY or `systemd-run --set-credential=`),
# more machinery than's worth wiring into a chroot for a one-time step.
{ ... }:
{
  boot.initrd.systemd.enable = true;
}
