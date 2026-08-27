# Disk layout, reproducing install.sh's partitioning:
#   GPT: partition 1 = LUKS2-on-BTRFS (rest of disk minus 511MiB), partition 2 = ESP
#   BTRFS subvolumes: root, home, nix (was the pacman pkg cache), docker, logs,
#   tmp, swap, snapshots - same mount options (noatime,nodiratime,discard,compress=zstd).
#
# EDIT `disk` below to the real block device before installing (e.g. /dev/nvme0n1).
#
# Detached LUKS header / YubiKey FIDO2 (optional, matches the old installer's
# advanced options): if you want the header on a separate device, change
# `content.extraOpenArgs` to include `[ "--header" "/dev/disk/by-id/<header-device>" ]`
# and set `settings.header` accordingly; see modules/luks-common.nix for the
# FIDO2 enrollment step.
{ disk ? "/dev/nvme0n1", swapSize ? "16G", ... }:
{
  disko.devices = {
    disk.main = {
      device = disk;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          primary = {
            size = "100%";
            content = {
              type = "luks";
              name = "luks";
              settings.allowDiscards = true;
              extraOpenArgs = [ ];
              content = {
                type = "btrfs";
                extraArgs = [ "-L" "btrfs" ];
                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = [ "noatime" "nodiratime" "discard" "compress=zstd" ];
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = [ "noatime" "nodiratime" "discard" "compress=zstd" ];
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "noatime" "nodiratime" "discard" "compress=zstd" ];
                  };
                  "/docker" = {
                    mountpoint = "/var/lib/docker";
                    mountOptions = [ "noatime" "nodiratime" "discard" "compress=zstd" ];
                  };
                  "/logs" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "noatime" "nodiratime" "discard" "compress=zstd" ];
                  };
                  "/tmp" = {
                    mountpoint = "/var/tmp";
                    mountOptions = [ "noatime" "nodiratime" "discard" "compress=zstd" ];
                  };
                  "/swap" = {
                    mountpoint = "/swap";
                    mountOptions = [ "noatime" "nodiratime" "discard" "compress=zstd" ];
                    # Default (16G) matches physical RAM for hibernation support
                    # (was `free --mebi` in install.sh) - override for smaller
                    # disks, e.g. test VMs, via the swapSize argument:
                    #   nixos-install ... (or disko directly) --argstr swapSize "4G"
                    swap.swapfile.size = swapSize;
                  };
                  "/snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = [ "noatime" "nodiratime" "discard" "compress=zstd" ];
                  };
                };
              };
            };
          };
          ESP = {
            label = "ESP";
            size = "511M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/efi";
            };
          };
        };
      };
    };
  };
}
