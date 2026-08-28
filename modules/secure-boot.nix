# Secure Boot, replacing the `sbctl create-keys && sbctl enroll-keys -m` calls
# from the old install.sh with lanzaboote (which still uses sbctl under the hood
# to manage the key bundle, it just wires signing into the NixOS build).
# Set couldinho.secureBoot = false per-host to skip all of this (plain
# systemd-boot instead) - see modules/options.nix.
#
# The sbctl key bundle can't be created before this host's very first
# nixos-install, since sbctl itself only exists in the target's store once
# that install has built and copied the system - but lanzaboote needs the
# bundle to sign the bootloader it installs as part of that same command.
# bootstrap.sh resolves this by running nixos-install with --no-bootloader,
# creating the keys via a chroot in the gap, then installing the bootloader
# as an explicit final step. If you're redoing this by hand instead of via
# bootstrap.sh (cannot be made fully declarative either way - it enrolls
# keys into firmware):
#   sudo nixos-enter --root /mnt -c 'sbctl create-keys && sbctl enroll-keys --microsoft'
#   sudo nixos-enter --root /mnt -c '/run/current-system/bin/switch-to-configuration boot'
# enroll-keys needs the firmware already in "Setup Mode" to accept new keys -
# if it fails, go into firmware Secure Boot settings, clear/reset the
# existing keys to re-enter Setup Mode, and retry both commands above.
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
