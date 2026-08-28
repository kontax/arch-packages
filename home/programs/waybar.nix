{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.waybar ];

  xdg.configFile."waybar/config".source = ../../conf/desktop/etc/xdg/waybar/config;
  # laptop profile overrides this with conf/laptop/etc/xdg/waybar/extra.conf
  xdg.configFile."waybar/extra.conf".source =
    lib.mkDefault ../../conf/desktop/etc/xdg/waybar/extra.conf;
  xdg.configFile."waybar/style.css".source = ../../conf/desktop/etc/xdg/waybar/style.css;

  systemd.user.services.waybar = {
    Unit = {
      Description = "Highly customizable Wayland bar for sway and wlroots based compositors";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar";
      Restart = "on-failure";
      RestartSec = "3s";
      # GTK_THEME (modules/profiles/desktop.nix) is inherited from the user
      # session by default - confirmed on real hardware, once it started
      # applying to waybar (a GTK3 app under the hood), the Gruvbox-Dark
      # theme's own gtk.css overrode font-size for button-based widgets with
      # higher specificity than this repo's style.css, shrinking
      # sway/workspaces' per-window icons (the only module using real GTK
      # buttons, everything else is plain labels) to roughly half size.
      # GTK CSS has no !important (tried it - hard parse error, crashes
      # waybar outright rather than warning and skipping). waybar is fully
      # self-themed via style.css already and never needed the system GTK
      # theme, so just don't inherit it here instead of fighting the
      # theme's specificity.
      UnsetEnvironment = "GTK_THEME";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.waybar-updates = {
    Unit.Description = "Refresh list of outdated packages in waybar";
    Service.ExecStart = "${pkgs.couldinho-desktop-scripts}/bin/waybar-updates refresh";
  };

  systemd.user.timers.waybar-updates = {
    Unit.Description = "Periodically refresh list of outdated packages in waybar";
    Timer = {
      OnCalendar = "00/6:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
