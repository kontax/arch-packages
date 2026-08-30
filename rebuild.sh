#!/usr/bin/env bash
# Rebuilds and switches the given (or current) host with whatever's
# currently edited - the everyday counterpart to update.sh, which only
# covers bumping flake inputs. Every rebuild up to now was a hand-typed
# `sudo nixos-rebuild switch ...`, with none of update.sh's protection
# against a forgotten `git add` on a new file silently vanishing from
# flake evaluation.
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
# file is silently invisible to evaluation, not an error. --intent-to-add
# marks every new path as tracked without staging its actual content, so
# git status/diff still show real edits as normal pending changes - see
# update.sh's own copy of this comment for the full explanation.
echo "==> Staging new files so the flake can see them"
git add --intent-to-add --all

echo
echo "==> Rebuilding and switching (flake: $REPO_DIR#$HOST)"
# --impure: flake.nix reads ~/.config/couldinho/local.nix via $HOME/SUDO_USER
# - see its own comments for why sudo alone doesn't preserve this.
sudo nixos-rebuild switch --flake ".?submodules=1#$HOST" --impure

echo
echo "==> Refreshing the waybar updates widget"
waybar-updates refresh 2>/dev/null || true

echo
echo "==> Done."
