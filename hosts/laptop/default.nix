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

  couldinho.user = "james";

  # was hidpi=Yes -> FONT=ter-132n
  console.font = lib.mkForce "ter-132n";

  system.stateVersion = "24.05";
}
