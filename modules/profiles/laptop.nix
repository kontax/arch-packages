# Everything from pkg/PKGBUILD's package_couldinho-laptop() + .install.
{ config, lib, pkgs, ... }:
let
  cfg = config.couldinho;
in
{
  environment.systemPackages = with pkgs; [
    acpilight # was `light` (haikarainen/light unpackaged; this is the maintained fork)
    wlsunset
    wluma
    couldinho-laptop-scripts # rofi-bluetooth
  ];

  services.tlp.enable = true;

  # was standalone `iwd` package alongside NetworkManager - use NM's iwd
  # backend rather than running two competing wifi daemons
  networking.networkmanager.wifi.backend = "iwd";

  hardware.bluetooth = {
    enable = true;
    settings = {
      General.Experimental = true;
      Policy.AutoEnable = true;
    };
  };

  # was pulseaudio-bluetooth - the desktop profile now uses PipeWire, whose
  # WirePlumber session manager handles bluetooth output switching natively,
  # so no pulseaudioFull / module-switch-on-connect workaround is needed.
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [ pkgs.sof-firmware ];

  environment.etc."X11/xorg.conf.d/40-libinput.conf".source =
    ../../conf/laptop/usr/share/X11/xorg.conf.d/40-libinput.conf;

  home-manager.users.${cfg.user}.xdg.configFile."waybar/extra.conf".source =
    lib.mkForce ../../conf/laptop/etc/xdg/waybar/extra.conf;
}
