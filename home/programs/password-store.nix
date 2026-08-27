# Clones/updates the personal `pass` store and writes the pass-git-helper
# mapping that tells git which pass entry backs which remote host - both
# personal information that doesn't belong hardcoded in this public repo,
# set via ~/.config/couldinho/local.nix instead (see local.nix.example,
# same reasoning as gpg-import.nix). Getting the encrypted files and the
# routing config in place doesn't get you anything readable on its own -
# decrypting any of it still needs the GPG secret key from gpg-import.nix,
# physically present on a YubiKey for this setup.
{ osConfig, lib, pkgs, ... }:
let
  cfg = osConfig.couldinho.passwordStore;
in
lib.mkMerge [
  (lib.mkIf (cfg.mapping != null) {
    home.file.".config/pass-git-helper/git-pass-mapping.ini".text = cfg.mapping;
  })

  (lib.mkIf (cfg.url != null) {
    # Not fatal on failure - this repo also targets machines (VMs,
    # freshly-bootstrapped hosts) with no network path to a personal git
    # server and no YubiKey to auth with yet, and a failed activation
    # script would otherwise break every rebuild until that's sorted.
    home.activation.clonePasswordStore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -d "$HOME/.password-store/.git" ]; then
        $DRY_RUN_CMD ${pkgs.git}/bin/git -C "$HOME/.password-store" pull --ff-only ||
          echo "warning: couldn't update ~/.password-store" >&2
      else
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone "${cfg.url}" "$HOME/.password-store" ||
          echo "warning: couldn't clone ~/.password-store from ${cfg.url}" >&2
      fi
    '';
  })
]
