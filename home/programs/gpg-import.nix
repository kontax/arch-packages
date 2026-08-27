# Sets a personal GPG key to ultimately trusted, matching what the old
# private dotfiles' base.sh did after importing it. Assumes the key is
# already in the keyring by some other means - this only sets trust, it
# doesn't fetch/import anything. The key ID is personal information that
# doesn't belong hardcoded in this public repo - only does anything if
# couldinho.gpg.keyId is set via a local.nix at the repo root (gitignored,
# see local.nix.example).
{ osConfig, lib, pkgs, ... }:
let
  keyId = osConfig.couldinho.gpg.keyId;
in
lib.mkIf (keyId != null) {
  home.activation.trustPersonalGpgKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo -e "5\ny\n" | ${pkgs.gnupg}/bin/gpg --command-fd 0 --expert --edit-key "${keyId}" trust
  '';
}
