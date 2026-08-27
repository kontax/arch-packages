# Dual-monitor desktop: base + desktop + dev (was
# `user_system=(base desktop dev)` in the install.sh checklist).
{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    (import ./disko.nix { disk = "/dev/nvme0n1"; }) # EDIT to the real device
    ../../modules/profiles/base.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/dev.nix
  ];

  couldinho.user = "james";

  # Currently being tested in a Proxmox VM, where Secure Boot doesn't add
  # anything and Proxmox's OVMF virtual firmware has been finicky about
  # custom key enrollment persisting. Flip back to true (or delete this
  # line, since true is the default) once this host is real hardware.
  couldinho.secureBoot = false;

  # was hidpi=No -> FONT=ter-716n
  console.font = lib.mkForce "ter-716n";

  system.stateVersion = "24.05";
}
