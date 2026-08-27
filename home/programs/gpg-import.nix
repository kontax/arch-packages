# Imports a personal GPG key and sets it to ultimately trusted, matching what
# the old private dotfiles' base.sh did (`gpg --import` + `trust` level 5).
# The key ID/URL are personal information that don't belong hardcoded in this
# public repo - this only does anything if couldinho.gpg.keyId/keyUrl are set
# via a local.nix at the repo root (gitignored, see local.nix.example).
{ osConfig, lib, pkgs, ... }:
let
  keyId = osConfig.couldinho.gpg.keyId;
  keyUrl = osConfig.couldinho.gpg.keyUrl;
in
lib.mkIf (keyId != null && keyUrl != null) {
  home.activation.importPersonalGpgKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! ${pkgs.gnupg}/bin/gpg -k | grep -q "${keyId}"; then
      ${pkgs.curl}/bin/curl -sL "${keyUrl}" | ${pkgs.gnupg}/bin/gpg --import
      echo -e "5\ny\n" | ${pkgs.gnupg}/bin/gpg --command-fd 0 --expert --edit-key "${keyId}" trust
    fi
  '';
}
