# GDB frontend picker (sec profile). Of the three original tools, only GEF is
# currently packaged in nixpkgs - pwndbg and peda are GAPs (see MIGRATION.md).
# The gdb-gef/gdb-peda/gdb-pwndbg wrapper scripts are still bundled verbatim
# via couldinho-sec-scripts; gdb-peda/gdb-pwndbg just won't do anything useful
# until those tools are packaged/installed some other way.
{ pkgs, ... }:
let
  gdbinitText = ''
    define init-gef
    source ${pkgs.gef}/share/gef/gef.py
    end
    document init-gef
    Initializes GEF (GDB Enhanced Features)
    end
  '';
in
{
  home.packages = [ pkgs.gef ];

  # GDB >= 12 reads $XDG_CONFIG_HOME/gdb/gdbinit as a fallback for ~/.gdbinit,
  # but ship both so this doesn't depend on the exact GDB version in nixpkgs.
  home.file.".gdbinit".text = gdbinitText;
  xdg.configFile."gdb/gdbinit".text = gdbinitText;
}
