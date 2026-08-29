# Sway session: config vendored verbatim (it already contains
# `exec "systemctl --user import-environment; systemctl --user start sway-session.target"`,
# so we just need that target + the user services that WantedBy= it, matching
# the systemd unit files that used to ship in desktop/etc/systemd/user/*).
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    sway
    swaylock-effects
    swayidle
    swayr
    kanshi
    wdisplays
    swaybg
  ];

  xdg.configFile."sway/config".source = ../../conf/desktop/sway/config;
  xdg.configFile."swaylock/config".source = ../../conf/desktop/swaylock/config;

  systemd.user.targets.sway-session = {
    Unit = {
      Description = "Sway compositor session";
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
    };
  };

  systemd.user.services.kanshi = {
    Unit = {
      Description = "Start the kanshi profile service";
      PartOf = [ "graphical-session.target" ];
      # kanshi's monitor-output profiles are inherently machine-specific (real
      # dual-monitor desktop vs a laptop vs this VM's virtual display all need
      # different profiles), so no config is vendored here - same reasoning
      # as local.nix for personal values. Without this guard the service
      # crash-loops with "failed to parse config file" when the file doesn't
      # exist; skip starting entirely instead. Create
      # ~/.config/kanshi/config with your real output names and restart this
      # service once you have one.
      ConditionPathExists = "%h/.config/kanshi/config";
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.kanshi}/bin/kanshi";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

  systemd.user.services.swayidle = {
    Unit = {
      Description = "Idle manager for Wayland";
      Documentation = [ "man:swayidle(1)" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
            timeout 900 'pgrep -x swaylock || ${pkgs.swaylock-effects}/bin/swaylock -f -c 000000' \
            timeout 1200 'swaymsg "output * dpms off"' \
              resume 'swaymsg "output * dpms on"' \
            before-sleep 'swaymsg "output * dpms on"; pgrep -x swaylock || ${pkgs.swaylock-effects}/bin/swaylock -f -c 000000'
      '';
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

  systemd.user.services.swayr = {
    Unit = {
      Description = "swayr daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.swayr}/bin/swayrd";
      Restart = "always";
      RestartSec = "10s";
      StandardOutput = "null";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.sway-autoname-workspaces = {
    Unit = {
      Description = "Autoname sway workspaces";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.couldinho-desktop-scripts}/bin/sway-autoname-workspaces -d";
      Restart = "always";
      RestartSec = "10s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.sway-inactive-window-transparency = {
    Unit = {
      Description = "Make inactive windows in sway semi-transparent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.couldinho-desktop-scripts}/bin/sway-inactive-window-transparency";
      Restart = "always";
      RestartSec = "10s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
