# HiDPI laptop: base + desktop + laptop + dev (was
# `user_system=(base desktop laptop dev)` in the install.sh checklist).
{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    (import ./disko.nix { disk = "/dev/nvme0n1"; }) # EDIT to the real device
    ../../modules/profiles/base.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/laptop.nix
    ../../modules/profiles/dev.nix
  ];

  # was hidpi=Yes -> FONT=ter-132n
  console.font = lib.mkForce "ter-132n";

  # Makes the initrd actually attempt FIDO2 unlock at boot (touch the
  # YubiKey when it flashes) instead of only prompting for the passphrase -
  # disko.nix's "luks" device name has to match. The credential itself still
  # needs enrolling separately: `sudo systemd-cryptenroll --fido2-device=auto
  # --fido2-with-client-pin=false --wipe-slot=password
  # /dev/disk/by-partlabel/disk-main-primary` (bootstrap.sh offers this as an
  # optional step) - see modules/luks-common.nix.
  boot.initrd.luks.devices.luks.crypttabExtraOpts = [ "fido2-device=auto" ];

  system.stateVersion = "24.05";
}
