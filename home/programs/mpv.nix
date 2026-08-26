{ pkgs, ... }:
{
  home.packages = [ pkgs.mpv pkgs.yt-dlp ];

  xdg.configFile."mpv/mpv.conf".source = ../../conf/desktop/etc/mpv/mpv.conf;
  xdg.configFile."mpv/input.conf".source = ../../conf/desktop/etc/mpv/input.conf;
  xdg.configFile."mpv/script-opts/osc.conf".source = ../../conf/desktop/etc/mpv/script-opts/osc.conf;
  xdg.configFile."mpv/script-opts/uosc.conf".source = ../../conf/desktop/etc/mpv/script-opts/uosc.conf;
  xdg.configFile."mpv/scripts/uosc.lua".source = ../../conf/desktop/etc/mpv/scripts/uosc.lua;
  # was mpv-mpris; nixpkgs ships it as an mpv script package, not a standalone
  # binary. TODO: verify the exact output path once buildable - it may not be
  # $out/mpris.so directly (could be under lib/mpv/scripts/) - and fix this.
  xdg.configFile."mpv/scripts/mpris.so".source = "${pkgs.mpvScripts.mpris}/mpris.so";
}
