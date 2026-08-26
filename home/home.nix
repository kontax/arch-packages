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
  ];

  home.username = osConfig.couldinho.user;
  home.homeDirectory = "/home/${osConfig.couldinho.user}";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;
}
