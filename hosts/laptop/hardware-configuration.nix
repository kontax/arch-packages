# Placeholder. Generate the real file during install with:
#   nixos-generate-config --no-filesystems --root /mnt
# and copy the result over this file (filesystems are already declared by
# disko.nix, hence --no-filesystems - this file should only contain
# boot.initrd.availableKernelModules, kernelModules, cpu microcode, and
# hardware.cpu.*.updateMicrocode for the real hardware).
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
