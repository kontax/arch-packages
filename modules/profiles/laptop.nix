# Everything from pkg/PKGBUILD's package_couldinho-laptop() + .install.
{ config, lib, pkgs, ... }:
let
  cfg = config.couldinho;
in
{
  environment.systemPackages = with pkgs; [
    acpilight # was `light` (haikarainen/light unpackaged; this is the maintained fork)
    wlsunset
    couldinho-laptop-scripts # rofi-bluetooth
  ];

  # acpilight ships its own udev rule (chgrp video + chmod g+w on the
  # backlight sysfs brightness file) but a package's udev rules aren't
  # auto-registered just by installing it under NixOS the way they would be
  # via an Arch pacman hook - confirmed on real hardware, xbacklight failed
  # with a plain [Errno 13] Permission denied writing
  # /sys/class/backlight/intel_backlight/brightness with no rule active at
  # all.
  services.udev.packages = [ pkgs.acpilight ];

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

  # The Thunderbolt 4 dock exposes a USB audio sink whether or not anything
  # is plugged into its jack, and ALSA gives it a higher priority (1109) than
  # the built-in speakers (1009), so WirePlumber picked the empty dock as the
  # default output and nothing was audible. Rank it below the speakers; it can
  # still be picked by hand in pavucontrol.
  services.pipewire.wireplumber.extraConfig."51-dock-audio-low-priority" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          { "node.name" = "~alsa_output.usb-Lenovo_ThinkPad_Thunderbolt_4_Dock_USB_Audio.*"; }
        ];
        actions.update-props = {
          "priority.session" = 500;
          "priority.driver" = 500;
        };
      }
    ];
  };

  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [ pkgs.sof-firmware ];

  environment.etc."X11/xorg.conf.d/40-libinput.conf".source =
    ../../conf/laptop/share/X11/xorg.conf.d/40-libinput.conf;

  home-manager.users.${cfg.user}.xdg.configFile."waybar/extra.conf".source =
    lib.mkForce ../../conf/laptop/waybar/extra.conf;
}
