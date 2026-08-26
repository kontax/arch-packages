# Secure Boot, replacing the `sbctl create-keys && sbctl enroll-keys -m` calls
# from the old install.sh with lanzaboote (which still uses sbctl under the hood
# to manage the key bundle, it just wires signing into the NixOS build).
#
# One-time manual step after the first `nixos-rebuild switch` on new hardware
# (cannot be meaningfully declarative - it enrolls keys into firmware):
#   sudo sbctl create-keys
#   sudo sbctl enroll-keys --microsoft   # keep --microsoft unless you know you don't need it
# then reboot, enable Secure Boot + "Setup Mode" in firmware if required, and
# rebuild once more so the boot files get signed.
{ lib, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi"; # matches disko.nix's ESP mountpoint

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
