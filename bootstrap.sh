#!/usr/bin/env bash
# Installs one of the hosts defined in hosts/ onto a new machine, booted from
# a NixOS installer ISO with network access. Replaces the old dialog-driven
# install.sh - most of what that script asked interactively (hostname, user,
# disk layout, encryption, package set) is now declared in this repo instead;
# the only two things you still choose at install time are which host to
# build and the disk to partition (destructive - double check it).
set -euo pipefail
trap 's=$?; echo "$0: error on line $LINENO: $BASH_COMMAND"; exit $s' ERR

if [ ! -d /sys/firmware/efi/efivars ]; then
    echo "This must be run booted in UEFI mode." >&2
    exit 1
fi

HOST="${1:-}"
DISK="${2:-}"

if [ -z "$HOST" ]; then
    echo "Usage: $0 <host> <disk>" >&2
    echo "  <host> is one of: $(ls "$(dirname "$0")/hosts")" >&2
    echo "  <disk> e.g. /dev/nvme0n1 - THIS WILL BE WIPED" >&2
    exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_DIR="$REPO_DIR/hosts/$HOST"

if [ ! -d "$HOST_DIR" ]; then
    echo "No such host: $HOST (looked in $HOST_DIR)" >&2
    exit 1
fi

if [ -z "$DISK" ]; then
    echo "Available disks:"
    lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop"
    read -rp "Disk to partition (THIS WILL BE WIPED): " DISK
fi

echo
echo "==> Partitioning $DISK with disko (hosts/$HOST/disko.nix)"
nix --experimental-features 'nix-command flakes' run github:nix-community/disko -- \
    --mode destroy,format,mount \
    --argstr disk "$DISK" \
    "$HOST_DIR/disko.nix"

echo
echo "==> Generating hardware-configuration.nix"
nixos-generate-config --no-filesystems --root /mnt
echo "    Review /mnt/etc/nixos/hardware-configuration.nix and copy anything"
echo "    hardware-specific (extra kernel modules, non-Intel microcode, etc.)"
echo "    into $HOST_DIR/hardware-configuration.nix, then continue."
read -rp "Press enter once done: " _

echo
echo "==> Installing NixOS (flake: $REPO_DIR#$HOST)"
nixos-install --root /mnt --flake "$REPO_DIR#$HOST"

cat <<EOF

==> Done. Before rebooting, or on first login, still to do manually
    (same as the manual steps the old install.sh needed too):
      - set passwords:      passwd (as root, in the installed system)
      - Secure Boot:        sbctl create-keys && sbctl enroll-keys --microsoft
                             (see modules/secure-boot.nix)
      - YubiKey LUKS unlock: systemd-cryptenroll --fido2-device=auto ...
                             (see modules/luks-common.nix)
EOF
