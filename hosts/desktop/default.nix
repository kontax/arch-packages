# Dual-monitor desktop: base + desktop + dev (was
# `user_system=(base desktop dev)` in the install.sh checklist). Real
# hardware template - see hosts/desktop-vm for the Proxmox VM this was
# actually developed/tested against before deploying here.
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

  # was hidpi=No -> FONT=ter-716n
  console.font = lib.mkForce "ter-716n";

  system.stateVersion = "24.05";
}
