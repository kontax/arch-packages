# Secure Boot, replacing the `sbctl create-keys && sbctl enroll-keys -m` calls
# from the old install.sh with lanzaboote (which still uses sbctl under the hood
# to manage the key bundle, it just wires signing into the NixOS build).
# Set couldinho.secureBoot = false per-host to skip all of this (plain
# systemd-boot instead) - see modules/options.nix.
#
# One-time manual step after the first `nixos-rebuild switch` on new hardware
# (cannot be meaningfully declarative - it enrolls keys into firmware):
#   sudo sbctl create-keys
#   sudo sbctl enroll-keys --microsoft   # keep --microsoft unless you know you don't need it
# then reboot, enable Secure Boot + "Setup Mode" in firmware if required, and
# rebuild once more so the boot files get signed.
{ config, lib, pkgs, ... }:
let
  cfg = config.couldinho;
in
{
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi"; # matches disko.nix's ESP mountpoint

  boot.loader.systemd-boot.enable = lib.mkForce (!cfg.secureBoot);

  boot.lanzaboote = lib.mkIf cfg.secureBoot {
    enable = true;
    # sbctl's default key storage location moved from /etc/secureboot to
    # /var/lib/sbctl at some point - confirmed by `sbctl create-keys`
    # actually writing keys/db/db.pem etc. under /var/lib/sbctl on this
    # nixpkgs revision. Must match wherever `sbctl create-keys` really wrote
    # them, not just lanzaboote's own historical default.
    pkiBundle = "/var/lib/sbctl";
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
