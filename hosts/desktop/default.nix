# Dual-monitor desktop: base + desktop + dev + sec (was
# `user_system=(base desktop dev sec)` in the install.sh checklist).
{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    (import ./disko.nix { disk = "/dev/nvme0n1"; }) # EDIT to the real device
    ../../modules/profiles/base.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/dev.nix
    ../../modules/profiles/sec.nix
  ];

  couldinho.user = "james";

  # was hidpi=No -> FONT=ter-716n
  console.font = lib.mkForce "ter-716n";

  system.stateVersion = "24.05";
}
