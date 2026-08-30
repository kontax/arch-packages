# Overlay: packages this repo needs that don't come from nixpkgs as-is.
#
# The conf/<profile>/bin scripts (were usr/local/bin/* on the original Arch
# packages) are bundled verbatim (not rewritten/shellcheck-cleaned) into one
# derivation per profile, so their behaviour matches the Arch packages
# exactly. Each profile module adds its bundle to environment.systemPackages.
#
# Most of these scripts have Arch-style shebangs (`#!/bin/bash`, `#!/usr/bin/python`,
# or none at all) which don't resolve on NixOS - it only ships `/bin/sh` and
# `/usr/bin/env`. patchShebangs rewrites them to the interpreters below - each
# script's own shebang was also switched to `#!/usr/bin/env <interpreter>` so
# resolution doesn't depend on nixpkgs happening to ship a bare `python`/`bash`
# binary name matching the old literal `/usr/bin/python`/`/usr/bin/bash` paths.
final: prev:
let
  mkScriptBundle = { profile, dir, interpreters ? [ prev.bash prev.python3 ] }:
    prev.stdenvNoCC.mkDerivation {
      pname = "couldinho-${profile}-scripts";
      version = "1";
      dontUnpack = true;
      dontBuild = true;
      nativeBuildInputs = interpreters;
      installPhase = ''
        mkdir -p $out/bin
        cp -r --no-preserve=ownership -- ${dir}/. $out/bin/
        chmod +x $out/bin/*
        patchShebangs $out/bin
      '';
    };
in
{
  couldinho-base-scripts = mkScriptBundle {
    profile = "base";
    dir = ../conf/base/bin;
  };
  couldinho-desktop-scripts = mkScriptBundle {
    profile = "desktop";
    dir = ../conf/desktop/bin;
    # sway-autoname-workspaces / sway-inactive-window-transparency /
    # sway-workspace-monitors all `import i3ipc` - a bare pkgs.python3
    # doesn't have it on sys.path (unlike environment.systemPackages,
    # patchShebangs bakes in one fixed interpreter path, so it has to be
    # this wrapped one, not whatever's on PATH later).
    interpreters = [ prev.bash (prev.python3.withPackages (ps: [ ps.i3ipc ])) ];
  };
  couldinho-laptop-scripts = mkScriptBundle {
    profile = "laptop";
    dir = ../conf/laptop/bin;
  };

  # Upstream test suite bug, not a functional problem: udiskie's own pytest
  # suite (run by nixpkgs during the build) fails in udiskie/keyutils.py -
  # `ValueError: bytes length not a multiple of item size` reading back a
  # kernel keyring entry, against whatever kernel/keyutils behaviour this
  # build environment has. Doesn't affect the actual udiskie binary we ship,
  # just skips running its tests during the nixpkgs build.
  udiskie = prev.udiskie.overrideAttrs (_: { doCheck = false; });

  # Upstream packaging bug, not ours: gtk-3.0/gtk.css leaks one GTK4-only
  # property (its gtk-3.0 and gtk-4.0 variants are almost certainly
  # generated from shared SCSS source) - confirmed on real hardware, waybar
  # (a GTK3 app, home/programs/waybar.nix) logged "Theme parsing error:
  # gtk.css:1048:16: 'border-spacing' is not a valid property name".
  # Harmless (GTK skips the one invalid declaration and keeps going), but
  # strip it from every variant's gtk-3.0 stylesheet so it parses clean.
  gruvbox-gtk-theme = prev.gruvbox-gtk-theme.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      sed -i '/border-spacing: 6px;/d' $out/share/themes/*/gtk-3.0/gtk.css
    '';
  });
}
