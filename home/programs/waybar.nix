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
