# Overlay: packages this repo needs that don't come from nixpkgs as-is.
#
# The `usr/local/bin` scripts from the old conf/<profile> layout are bundled
# verbatim (not rewritten/shellcheck-cleaned) into one derivation per profile,
# so their behaviour matches the Arch packages exactly. Each profile module
# adds its bundle to environment.systemPackages.
final: prev:
let
  mkScriptBundle = profile: dir:
    prev.stdenvNoCC.mkDerivation {
      pname = "couldinho-${profile}-scripts";
      version = "1";
      dontUnpack = true;
      dontBuild = true;
      installPhase = ''
        mkdir -p $out/bin
        cp -r --no-preserve=ownership -- ${dir}/. $out/bin/
        chmod +x $out/bin/*
      '';
    };
in
{
  couldinho-base-scripts = mkScriptBundle "base" ../conf/base/usr/local/bin;
  couldinho-desktop-scripts = mkScriptBundle "desktop" ../conf/desktop/usr/local/bin;
  couldinho-laptop-scripts = mkScriptBundle "laptop" ../conf/laptop/usr/local/bin;
}
