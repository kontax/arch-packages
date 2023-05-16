#!/bin/bash
set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR


devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac | tr '\n' ' ')
echo -e "Choose a device to mount from the following:\n${devicelist}"
read device

part_root="$(ls ${device}* | grep -E "^${device}p?1$")"
part_boot="$(ls ${device}* | grep -E "^${device}p?2$")"
cryptsetup luksOpen --header $part_root $part_root luks
part_install=/dev/mapper/luks

mount -o noatime,nodiratime,discard,compress=zstd,subvol=root       ${part_install} /mnt
mount "${part_boot}" /mnt/efi
mount -o noatime,nodiratime,discard,compress=zstd,subvol=/          ${part_install} /mnt/mnt/btrfs-root
mount -o noatime,nodiratime,discard,compress=zstd,subvol=home       ${part_install} /mnt/home
mount -o noatime,nodiratime,discard,compress=zstd,subvol=pkgs       ${part_install} /mnt/var/cache/pacman
mount -o noatime,nodiratime,discard,compress=zstd,subvol=docker     ${part_install} /mnt/var/lib/docker
mount -o noatime,nodiratime,discard,compress=zstd,subvol=logs       ${part_install} /mnt/var/log
mount -o noatime,nodiratime,discard,compress=zstd,subvol=tmp        ${part_install} /mnt/var/tmp
mount -o noatime,nodiratime,discard,compress=zstd,subvol=swap       ${part_install} /mnt/swap
mount -o noatime,nodiratime,discard,compress=zstd,subvol=snapshots  ${part_install} /mnt/.snapshots
