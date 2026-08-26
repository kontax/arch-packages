# Everything from pkg/PKGBUILD's package_couldinho-sec() + .install.
# Gaps (no nixpkgs package / proprietary installer) are listed in MIGRATION.md:
# 010editor, caido-desktop, binaryninja-free, pwndbg, peda, pwngdb, r2ghidra,
# afl-utils.
{ config, lib, pkgs, ... }:
let
  cfg = config.couldinho;
in
{
  home-manager.users.${cfg.user}.imports = [ ../../home/programs/gdb.nix ];

  environment.systemPackages = with pkgs; [
    # Binary
    ltrace
    strace
    binwalk

    # Network
    nmap
    wireshark-cli
    wireshark
    burpsuite
    dirbuster
    wfuzz

    # Reversing
    radare2
    ida-free
    ghidra
    python3Packages.capstone
    python3Packages.unicorn
    python3Packages.keystone-engine
    python3Packages.ropper # was bare `ropper` - no top-level alias
    python3Packages.r2pipe

    # Cracking
    john

    # Fuzzing
    aflplusplus

    couldinho-sec-scripts # gdb-gef/gdb-peda/gdb-pwndbg, sway-split.py
  ];

  # NB: no system-wide /etc/gdb/gdbinit - the original file's `source
  # /usr/share/<tool>/...` paths only make sense on an FHS system. The
  # nix-store-path-corrected equivalent lives in home/programs/gdb.nix for
  # ${cfg.user}; root doesn't get gdb-gef/peda/pwndbg support automatically.

  xdg.mime.enable = true;
  home-manager.users.${cfg.user}.xdg.dataFile = {
    "applications/ida-free.desktop".source =
      ../../conf/sec/usr/local/share/applications/ida-free.desktop;
    "applications/010editor.desktop".source =
      ../../conf/sec/usr/local/share/applications/010editor.desktop;
    "applications/ghidra.desktop".source =
      ../../conf/sec/usr/local/share/applications/ghidra.desktop;
  };
}
