#!/usr/bin/env bash
# Installs one of the hosts defined in hosts/ onto a new machine, booted from
# a NixOS installer ISO with network access. Replaces the old dialog-driven
# install.sh - most of what that script asked interactively (hostname, user,
# disk layout, encryption, package set) is now declared in this repo instead;
# the only two things you still choose at install time are which host to
# build and the disk to partition (destructive - double check it). One more
# prerequisite this script can't do for you: ~/.config/couldinho/local.nix
# (see local.nix.example) needs to already exist, since couldinho.user has
# no default and every host reads it from there.
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

# Confirmed live, twice: a submodule checked out at one branch's path (e.g.
# while comparing .gitmodules across branches to chase an unrelated error)
# is left behind un-removed by a later `git checkout`, since git won't
# clean up a populated directory - the new branch's own submodule path
# then silently stays uninitialized, only surfacing much later as a
# confusing "path is not tracked by Git" flake evaluation error two steps
# from now. Failing fast here, before anything destructive happens, beats
# that.
CURRENT_BRANCH="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null)"
if [ "$CURRENT_BRANCH" != "master" ]; then
    echo "This checkout is on branch '$CURRENT_BRANCH', expected 'master'" >&2
    echo "(this flake's own branch, now that nixos has been merged in) -" >&2
    echo "run 'git -C $REPO_DIR checkout master' first." >&2
    exit 1
fi

# couldinho.user has no default (modules/options.nix) - every host reads it
# from ~/.config/couldinho/local.nix, which this script doesn't generate
# (it's meant to be hand-authored, and often carries more than just the
# username - a GPG key ID, password-store config). $HOME here is root's,
# since this script needs sudo - checked and evaluated now, before the
# destructive disko step, so a missing/broken local.nix fails fast instead
# of after the disk's already been wiped.
if [ ! -f "$HOME/.config/couldinho/local.nix" ]; then
    echo "No $HOME/.config/couldinho/local.nix found - copy" >&2
    echo "$REPO_DIR/local.nix.example there and fill it in (at minimum" >&2
    echo "couldinho.user), then rerun." >&2
    exit 1
fi
# --impure: without it, builtins.getEnv "HOME" in flake.nix silently returns
# "" instead of erroring (documented Nix behaviour for impure builtins under
# pure eval), so local.nix's path resolves to a bogus one at the filesystem
# root and never actually gets imported - couldinho.user then comes back
# completely undefined rather than this check ever catching a real problem.
PRIMARY_USER="$(nix --extra-experimental-features 'nix-command flakes' eval --impure --raw \
    "$REPO_DIR?submodules=1#nixosConfigurations.$HOST.config.couldinho.user")"

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
# ?submodules=1 is required: the nvim config (conf/base/nvim) is a
# git submodule, and Nix's git-tree filtering ignores submodule content
# unless asked for it - without this, evaluation fails with
# "Path '...xdg/nvim' ... is not tracked by Git".
#
# --no-bootloader: bootloader install is deferred to below, after Secure
# Boot signing keys exist if this host needs them (couldinho.secureBoot).
# lanzaboote needs an sbctl key bundle to sign against, and sbctl itself only
# exists in the target's store once nixos-install has built and copied the
# system - so those keys can't be created before this line runs, only
# between this line and the actual bootloader-install step. See
# modules/secure-boot.nix.
# --impure: same reason as the PRIMARY_USER eval above - without it,
# nixos-install would silently build with local.nix's values (couldinho.user
# included) unresolved rather than actually using them.
#
# --no-root-password: nixos-install prompts for root's password itself by
# default as its own final step - suppressed here since the explicit
# "Set root's password" step below already covers it, right next to the
# primary user's, rather than duplicating an unlabeled prompt mid-install.
nixos-install --root /mnt --flake "$REPO_DIR?submodules=1#$HOST" --no-bootloader --impure --no-root-password

# From here on the system is built and copied, just not yet bootable - none
# of the remaining steps should be able to abort the script and make that
# look like a fresh disko/nixos-install failure. Password entry and the
# final bootloader install are required, so they run unconditionally;
# Secure Boot key setup and YubiKey enrollment depend on things this script
# can't verify (firmware Setup Mode, a physically-present YubiKey) - if
# Secure Boot key setup fails, warn and keep going, since the bootloader
# install right after it will fail too and give a clearer, fatal signal
# that it still needs to be redone once the firmware issue is fixed.

SECURE_BOOT="$(nix --extra-experimental-features 'nix-command flakes' eval --impure \
    "$REPO_DIR?submodules=1#nixosConfigurations.$HOST.config.couldinho.secureBoot")"

echo
echo "==> Copying local.nix into $PRIMARY_USER's new home"
# $HOME/.config/couldinho/local.nix (checked for above) only satisfied this
# script's own evaluation, running as root on the live ISO's ephemeral
# filesystem - /home/$PRIMARY_USER on the target disk is a different user,
# a different home, and after reboot a different filesystem entirely.
# Without this, the very first nixos-rebuild switch on the installed system
# would hit the exact same missing-local.nix failure all over again.
# mkdir -p runs directly (not via nixos-enter), so it creates .config as
# root on the live ISO's view of /mnt - only chowning the couldinho
# subdirectory afterward left the parent .config itself root-owned, which
# is enough to break every later home-manager write under it (sway, waybar,
# etc. all live under ~/.config) - confirmed on real hardware, home-manager
# activation silently stopped at the first one it couldn't write.
mkdir -p "/mnt/home/$PRIMARY_USER/.config/couldinho"
cp "$HOME/.config/couldinho/local.nix" "/mnt/home/$PRIMARY_USER/.config/couldinho/local.nix"
nixos-enter --root /mnt -c \
    "chown -R $PRIMARY_USER:users /home/$PRIMARY_USER/.config && chmod 600 /home/$PRIMARY_USER/.config/couldinho/local.nix"

echo
echo "==> Cloning this flake into $PRIMARY_USER's new home"
# waybar-updates (conf/desktop/bin/waybar-updates) and README.md's rebuild
# instructions both assume a working checkout at ~/dev/arch-packages - the
# live ISO's own checkout at $REPO_DIR only exists on its ephemeral
# filesystem, gone after reboot. --local hardlinks objects instead of
# copying them, so this is fast and fully offline even though $REPO_DIR may
# carry a substantial history. Same chown-the-parent-directory reasoning as
# .config above: mkdir -p runs as root on the live ISO's view of /mnt, and
# chowning only the arch-packages subdirectory afterward would leave
# ~/dev itself root-owned.
mkdir -p "/mnt/home/$PRIMARY_USER/dev"
# --branch nixos: this flake only exists on that branch (master is the old
# pre-NixOS repo, no flake.nix at all) - pinned explicitly rather than
# relying on whatever $REPO_DIR's working tree happens to have checked out
# by this point in the script. Confirmed live, twice: mid-install
# troubleshooting (comparing .gitmodules between branches to chase the
# submodule error two paragraphs up) can leave $REPO_DIR sitting on
# master by the time this line runs, and a plain `git clone --local`
# silently clones whatever branch that is - no error, just a
# flake-less checkout that only surfaces as confusing symptoms much later
# (nothing in ~/dev/arch-packages resembling the NixOS repo).
git clone --local --branch nixos "$REPO_DIR" "/mnt/home/$PRIMARY_USER/dev/arch-packages"
git -C "/mnt/home/$PRIMARY_USER/dev/arch-packages" submodule update --init
nixos-enter --root /mnt -c \
    "chown -R $PRIMARY_USER:users /home/$PRIMARY_USER/dev"

echo
echo "==> Set root's password"
nixos-enter --root /mnt -c 'passwd'
echo
echo "==> Set $PRIMARY_USER's password"
nixos-enter --root /mnt -c "passwd $PRIMARY_USER"

if [ "$SECURE_BOOT" = "true" ]; then
    echo
    echo "==> Setting up Secure Boot signing keys (needs the firmware in Setup Mode)"
    # --ignore-immutable: confirmed live, enrolling keys from inside
    # nixos-enter's chroot hits "file is immutable" writing the efivarfs
    # key database entries even in genuine Setup Mode - something about how
    # the chroot's mount namespace exposes /sys/firmware/efi/efivars stops
    # sbctl's own automatic immutable-flag handling from working. Not
    # needed (and sbctl doesn't take the flag) outside a chroot.
    if ! nixos-enter --root /mnt -c 'sbctl create-keys && sbctl enroll-keys --microsoft --ignore-immutable'; then
        echo "    Secure Boot key setup failed - see modules/secure-boot.nix for the" >&2
        echo "    manual steps. The bootloader install right after this will fail too" >&2
        echo "    until it's fixed; once the firmware's in Setup Mode, rerun:" >&2
        echo "      sudo nixos-enter --root /mnt -c 'sbctl create-keys && sbctl enroll-keys --microsoft --ignore-immutable'" >&2
        echo "      sudo nixos-enter --root /mnt -c '/run/current-system/bin/switch-to-configuration boot'" >&2
    fi
fi

echo
echo "==> Installing the bootloader"
# Not wrapped in a soft-fail check like the steps above - without this, the
# disk has no working boot entry at all, so a failure here has to actually
# stop the script rather than let it reach "Done, reboot when ready" with a
# machine that can't boot.
nixos-enter --root /mnt -c '/run/current-system/bin/switch-to-configuration boot'

# Not attempted here, even though the key may already be plugged in: adding
# a FIDO2 unlock slot needs the existing disk passphrase to authorize it,
# and a PIN-protected key also needs its PIN to create the credential at
# all. Both are systemd-cryptenroll's own interactive ask-password prompts,
# which can't reach a terminal from inside the nixos-enter chroot used
# throughout this script (no systemd instance in there to service the
# request - "Failed to query password"/"Failed to acquire user PIN: No such
# file or directory"). There's no environment-variable override for this -
# systemd-cryptenroll's actual non-interactive mechanism is its own
# credentials system (cryptenroll.passphrase, cryptenroll.fido2-pin, loaded
# via $CREDENTIALS_DIRECTORY or `systemd-run --set-credential=`), which is
# more machinery than is worth wiring into a chroot for a one-time step -
# see modules/luks-common.nix for the plain command to run after reboot,
# where it prompts normally.
cat <<EOF

==> YubiKey LUKS enrollment (optional, not done by this script)
After rebooting and logging in, with the key plugged in:
  sudo systemd-cryptenroll --fido2-device=auto --fido2-with-client-pin=false \\
      --wipe-slot=password /dev/disk/by-partlabel/disk-main-primary
See modules/luks-common.nix.
EOF

cat <<EOF

==> Password store
home/programs/password-store.nix clones ~/.password-store via SSH,
authenticated by the YubiKey's Authenticate subkey through gpg-agent - that
needs a real login session (for gpg-agent's SSH socket to exist) and the
key physically present, neither of which this script's first activation
has. It's non-fatal on failure and retried on every "nixos-rebuild switch",
so log in, plug the key in, and rebuild once (even with no other changes)
to pick it up if it didn't clone automatically.
EOF

cat <<EOF

==> Done. Reboot when ready.
EOF
