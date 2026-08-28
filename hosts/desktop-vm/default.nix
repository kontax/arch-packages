# Proxmox VM used to test the desktop host's config before deploying to real
# hardware - everything here is tuned for that VM specifically. Shares
# ../desktop/disko.nix's disk layout logic (identical subvolumes/mount
# options, just different disk device + swap size arguments) rather than
# duplicating it. See hosts/desktop for the untouched real-hardware template
# this is based on.
{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    # This VM's disk shows up as /dev/sda (not nvme-style), and it's a 32G
    # disk - the default 32G swapfile alone would fill it, causing
    # disk-full/I/O errors partway through install.
    (import ../desktop/disko.nix { disk = "/dev/sda"; swapSize = "2G"; })
    ../../modules/profiles/base.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/dev.nix
  ];

  # Secure Boot doesn't add anything in a VM (the hypervisor already fully
  # controls the guest), and Proxmox's OVMF virtual firmware has been finicky
  # about custom key enrollment persisting.
  couldinho.secureBoot = false;

  # was hidpi=No -> FONT=ter-716n
  console.font = lib.mkForce "ter-716n";

  system.stateVersion = "24.05";
}
