#!/usr/bin/env bash
# Updates this flake's inputs, rebuilds/switches on the given (or current)
# host, and commits the resulting flake.lock. The write side of
# conf/desktop/bin/waybar-updates, which only reports what's pending.
set -euo pipefail
trap 's=$?; echo "$0: error on line $LINENO: $BASH_COMMAND"; exit $s' ERR

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="${1:-$(hostname)}"

if [ ! -d "$REPO_DIR/hosts/$HOST" ]; then
    echo "No such host: $HOST (looked in $REPO_DIR/hosts/$HOST)" >&2
    echo "Usage: $0 [host]" >&2
    echo "  [host] defaults to the current hostname ($(hostname)) - one of:" >&2
    echo "  $(ls "$REPO_DIR/hosts" | tr '\n' ' ')" >&2
    exit 1
fi

cd "$REPO_DIR"

# Nix flakes only evaluate files git already knows about - an untracked new
# file is silently invisible to evaluation, not an error, so a forgotten
# `git add` reads as "my change didn't apply" with no clue why. --intent-to-add
# marks every new path as tracked (fixing that) without staging its actual
# content - `git status`/`git diff` still show real edits as normal pending
# changes, unlike a plain `git add -A` which would stage content too.
echo "==> Staging new files so the flake can see them"
git add --intent-to-add --all

echo "==> Updating flake inputs"
nix --extra-experimental-features 'nix-command flakes' flake update

if git diff --quiet -- flake.lock; then
    echo "Nothing changed - already up to date."
    exit 0
fi

echo
# pam_u2f's per-user credential file isn't part of this repo (personal,
# tied to a specific physical key) and doesn't survive a fresh install -
# without it, sudo silently falls back to a password prompt instead of a
# YubiKey touch. Confirmed live, repeatedly, across every fresh bootstrap
# so far. pamu2fcfg needs a real interactive PIN prompt and a physical
# touch, so this only helps when run from an actual terminal - which is
# exactly how this script is meant to be run.
if [ ! -f "$HOME/.config/Yubico/u2f_keys" ]; then
    echo "==> Enrolling this YubiKey for sudo/polkit touch-to-confirm (pam_u2f)"
    mkdir -p "$HOME/.config/Yubico"
    pamu2fcfg >> "$HOME/.config/Yubico/u2f_keys"
    echo
fi

echo "==> Rebuilding and switching (flake: $REPO_DIR#$HOST)"
# --impure: flake.nix reads ~/.config/couldinho/local.nix via $HOME/SUDO_USER
# - see its own comments for why sudo alone doesn't preserve this.
sudo nixos-rebuild switch --flake ".?submodules=1#$HOST" --impure

echo
echo "==> Refreshing the waybar updates widget"
waybar-updates refresh 2>/dev/null || true

echo
# home/programs/gpg-import.nix only imports the public key and sets trust -
# it never touches the card, so the local secret-key stub that links a
# keygrip to this physical YubiKey (~/.gnupg/private-keys-v1.d/*.key) doesn't
# exist until something runs a card-aware gpg operation at least once.
# Confirmed live, on every fresh bootstrap so far: the commit below is
# usually the very first thing that tries to sign with this key, and it
# failed outright ("Unusable secret key" / INV_SGNR) with no such stub yet.
# --card-status creates it as a side effect, same as pamu2fcfg above is a
# one-time "prime this from a real terminal" step.
gpg --card-status >/dev/null 2>&1 || true

echo "==> Committing flake.lock"
git add flake.lock
git commit -m "Update flake inputs"

echo
echo "==> Done."
