# The nvim config is its own git submodule (conf/base/nvim, tracked in
# .gitmodules) - kept as an opaque vendored directory rather than converted to
# Nix. Run `git submodule update --init` before building this flake.
{ pkgs, ... }:
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
    # nvim-treesitter shells out to the `tree-sitter` CLI to compile parsers
    # - confirmed live, missing entirely: "Error during tree-sitter build:
    # ENOENT: no such file or directory (cmd): 'tree-sitter'".
    tree-sitter
  ];

  # lazy-lock.json's writability is handled by lazy_init.lua itself (seeds a
  # copy under stdpath("data") and points lazy at that instead), so the
  # vendored copy here can stay a plain read-only store symlink like the
  # rest of the tree - it's only ever read once, to seed that writable copy.
  xdg.configFile."nvim" = {
    source = ../../conf/base/nvim;
    recursive = true;
  };
}
