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
SWAP_SIZE="${3:-}"

if [ -z "$HOST" ]; then
    echo "Usage: $0 <host> <disk> [swap-size]" >&2
    echo "  <host> is one of: $(ls "$(dirname "$0")/hosts")" >&2
    echo "  <disk> e.g. /dev/nvme0n1 - THIS WILL BE WIPED" >&2
    echo "  [swap-size] overrides the host's default swapfile size (e.g. 2G)" >&2
    echo "  - must match whatever hosts/<host>/default.nix passes to disko.nix" >&2
    echo "    for this same host, or later nixos-rebuild switch runs will try" >&2
    echo "    to resize the swapfile back to the flake's declared size." >&2
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
DISKO_ARGS=(--argstr disk "$DISK")
if [ -n "$SWAP_SIZE" ]; then
    DISKO_ARGS+=(--argstr swapSize "$SWAP_SIZE")
fi
nix --experimental-features 'nix-command flakes' run github:nix-community/disko -- \
    --mode destroy,format,mount \
    "${DISKO_ARGS[@]}" \
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
# ?submodules=1 is required: the nvim config (conf/base/etc/xdg/nvim) is a
# git submodule, and Nix's git-tree filtering ignores submodule content
# unless asked for it - without this, evaluation fails with
# "Path '...xdg/nvim' ... is not tracked by Git".
nixos-install --root /mnt --flake "$REPO_DIR?submodules=1#$HOST"

# From here on, the OS is already successfully installed - none of the
# remaining steps should be able to abort the script and make that look like
# it failed. Password entry is essentially required, so it runs
# unconditionally; Secure Boot / YubiKey enrollment depend on things this
# script can't verify (firmware Setup Mode, a physically-present YubiKey), so
# they're opt-in and any failure just warns instead of aborting.

PRIMARY_USER="$(nix --extra-experimental-features 'nix-command flakes' eval --raw \
    "$REPO_DIR?submodules=1#nixosConfigurations.$HOST.config.couldinho.user")"

echo
echo "==> Set root's password"
nixos-enter --root /mnt -c 'passwd'
echo
echo "==> Set $PRIMARY_USER's password"
nixos-enter --root /mnt -c "passwd $PRIMARY_USER"

echo
read -rp "Set up Secure Boot signing keys now? [y/N] " _sb
if [[ "$_sb" =~ ^[Yy]$ ]]; then
    echo "    (needs the firmware in Setup Mode - see modules/secure-boot.nix)"
    if ! nixos-enter --root /mnt -c 'sbctl create-keys && sbctl enroll-keys --microsoft'; then
        echo "    Secure Boot key setup failed - see modules/secure-boot.nix for the" >&2
        echo "    manual steps and retry once the firmware is in Setup Mode." >&2
    fi
fi

echo
read -rp "Enroll a YubiKey for LUKS unlock now (key must be plugged in)? [y/N] " _yk
if [[ "$_yk" =~ ^[Yy]$ ]]; then
    if ! nixos-enter --root /mnt -c \
        'systemd-cryptenroll --fido2-device=auto --fido2-with-client-pin=false --wipe-slot=password /dev/disk/by-partlabel/primary'; then
        echo "    YubiKey enrollment failed - see modules/luks-common.nix for the" >&2
        echo "    manual command and retry once the key is plugged in." >&2
    fi
fi

cat <<EOF

==> Done. Reboot when ready.
EOF
