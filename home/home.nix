# Home-manager entrypoint for the primary desktop user. Wired in from
# modules/profiles/desktop.nix via `home-manager.users.${cfg.user}`.
{ osConfig, ... }:
{
  imports = [
    ./programs/sway.nix
    ./programs/waybar.nix
    ./programs/desktop.nix
    ./programs/kitty.nix
    ./programs/mpv.nix
    ./programs/nvim.nix
    ./programs/gpg-import.nix
    ./programs/password-store.nix
    ./programs/git.nix
    ./programs/atuin.nix
  ];

  home.username = osConfig.couldinho.user;
  home.homeDirectory = "/home/${osConfig.couldinho.user}";
  home.stateVersion = "24.05";

  # zsh has its own separate "unconfigured user" wizard (distinct from the
  # powerlevel10k one in base.nix) that triggers whenever a per-user
  # ~/.zshrc doesn't exist, regardless of the system-wide /etc/zshrc that
  # programs.zsh already manages. An empty file is enough to satisfy the
  # check - the actual shell config still comes entirely from /etc/zshrc.
  home.file.".zshrc".text = "";

  programs.home-manager.enable = true;
}
