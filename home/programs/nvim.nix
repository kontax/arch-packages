# The nvim config is its own git submodule (conf/base/nvim, tracked in
# .gitmodules) - kept as an opaque vendored directory rather than converted to
# Nix. Run `git submodule update --init` before building this flake.
{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    neovim
    python3Packages.pynvim
    # LuaSnip's optional jsregexp build step shells out to `make` (and a C
    # compiler) - confirmed live, missing entirely: "build failed, zsh:1:
    # command not found: make". Arch's base-devel pulled this in
    # unconditionally; NixOS doesn't unless something asks for it.
    gnumake
    gcc
  ];

  # lazy-lock.json is excluded here and handled as its own separate entry
  # below - a plain xdg.configFile override at "nvim/lazy-lock.json"
  # alongside this recursive one doesn't actually take precedence
  # (confirmed live: home-manager's own generated per-file symlink for that
  # path inside this recursive tree wins regardless), so the only way to
  # give it different handling is to not have this recursive copy include
  # it in the first place.
  xdg.configFile."nvim" = {
    source = pkgs.runCommand "nvim-config-minus-lock" { } ''
      cp -r ${../../conf/base/nvim} $out
      chmod -R u+w $out
      rm -f $out/lazy-lock.json
    '';
    recursive = true;
  };

  # lazy.nvim rewrites this after every plugin install/update - as part of
  # the recursive tree above it would be a read-only Nix store symlink like
  # everything else there (it's a real file tracked in the submodule, not
  # something generated at runtime). Confirmed live: "lazy-lock.json:
  # Read-only file system" the moment a plugin tried to install. Pointing
  # at the real submodule file instead of a store copy keeps it seeded with
  # the pinned versions the submodule tracks, but genuinely writable -
  # lazy.nvim's own updates land as an uncommitted change in the submodule
  # checkout, same as any other edit there, rather than failing outright.
  xdg.configFile."nvim/lazy-lock.json".source =
    config.lib.file.mkOutOfStoreSymlink
      (config.home.homeDirectory + "/dev/arch-packages/conf/base/nvim/lazy-lock.json");
}
