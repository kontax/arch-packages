# The nvim config is its own git submodule (conf/base/etc/xdg/nvim, tracked in
# .gitmodules) - kept as an opaque vendored directory rather than converted to
# Nix. Run `git submodule update --init` before building this flake.
{ pkgs, ... }:
{
  home.packages = with pkgs; [ neovim python3Packages.pynvim ];

  xdg.configFile."nvim" = {
    source = ../../conf/base/etc/xdg/nvim;
    recursive = true;
  };
}
