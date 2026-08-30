# Personal git identity (user.name/user.email) doesn't belong hardcoded in
# this public repo - same reasoning as gpg-import.nix/password-store.nix,
# set via ~/.config/couldinho/local.nix (see local.nix.example). Layers on
# top of /etc/gitconfig (modules/profiles/base.nix - credential.helper,
# delta, commit.gpgsign, etc., all shared and not personal) rather than
# duplicating it: git reads system config first, then this per-user one
# (home-manager writes it to ~/.config/git/config), so the same keys in
# either file just have the per-user one win.
{ osConfig, lib, ... }:
lib.mkIf (osConfig.couldinho.git.userName != null) {
  programs.git = {
    enable = true;
    settings.user = {
      name = osConfig.couldinho.git.userName;
      email = osConfig.couldinho.git.userEmail;
    };
  };
}
