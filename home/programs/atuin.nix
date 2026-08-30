# Searchable, timestamped shell history (local SQLite db, no sync server
# configured - see https://docs.atuin.sh if you want cross-machine sync
# later), replacing plain zsh history.
#
# enableZshIntegration is left off deliberately: it only wires into
# home-manager's own programs.zsh module, which this repo doesn't use -
# zsh is entirely NixOS-level (modules/profiles/base.nix). The actual
# shell hook is added there directly instead.
{
  programs.atuin = {
    enable = true;
    enableZshIntegration = false;
    settings = {
      update_check = false;
      style = "compact";
    };
  };
}
