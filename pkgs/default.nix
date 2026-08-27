# Overlay: packages this repo needs that don't come from nixpkgs as-is.
#
# The `usr/local/bin` scripts from the old conf/<profile> layout are bundled
# verbatim (not rewritten/shellcheck-cleaned) into one derivation per profile,
# so their behaviour matches the Arch packages exactly. Each profile module
# adds its bundle to environment.systemPackages.
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
    dir = ../conf/base/usr/local/bin;
  };
  couldinho-desktop-scripts = mkScriptBundle {
    profile = "desktop";
    dir = ../conf/desktop/usr/local/bin;
    # sway-autoname-workspaces / sway-inactive-window-transparency `import i3ipc` -
    # a bare pkgs.python3 doesn't have it on sys.path (unlike
    # environment.systemPackages, patchShebangs bakes in one fixed interpreter
    # path, so it has to be this wrapped one, not whatever's on PATH later).
    interpreters = [ prev.bash (prev.python3.withPackages (ps: [ ps.i3ipc ])) ];
  };
  couldinho-laptop-scripts = mkScriptBundle {
    profile = "laptop";
    dir = ../conf/laptop/usr/local/bin;
  };

  # Upstream test suite bug, not a functional problem: udiskie's own pytest
  # suite (run by nixpkgs during the build) fails in udiskie/keyutils.py -
  # `ValueError: bytes length not a multiple of item size` reading back a
  # kernel keyring entry, against whatever kernel/keyutils behaviour this
  # build environment has. Doesn't affect the actual udiskie binary we ship,
  # just skips running its tests during the nixpkgs build.
  udiskie = prev.udiskie.overrideAttrs (_: { doCheck = false; });
}
