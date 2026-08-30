# Notification daemon, launcher, mimetypes, GTK theme, and the small
# session-glue services that used to be desktop/etc/systemd/user/*.service.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    swaynotificationcenter # was swaync (attr renamed upstream, binary is still `swaync`)
    fuzzel
    libnotify
    udiskie
    gsimplecal
    qalculate-gtk
    inotify-tools
    yubikey-touch-detector
    qrencode
    progress
    # Was missing entirely - rofi-bluetooth (couldinho-laptop-scripts) calls
    # bare `rofi`, which had no provider anywhere in this flake. Worked for
    # pinentry-rofi only because that package wraps its own private rofi
    # runtime dependency, invisible outside its own wrapper.
    rofi
    # gtk-3.0/settings.ini names gtk-theme-name=Arc-Gruvbox - a confirmed
    # migration gap (MIGRATION.md), never packaged for NixOS, so GTK apps
    # (pavucontrol included) silently fell back to stock Adwaita. Not a
    # drop-in match for the old Arc-Gruvbox theme, but close in spirit and
    # actually packaged.
    gruvbox-gtk-theme
  ];

  xdg.configFile."swaync/config.json".source = ../../conf/desktop/swaync/config.json;
  xdg.configFile."swaync/style.css".source = ../../conf/desktop/swaync/style.css;
  xdg.configFile."fuzzel/fuzzel.ini".source = ../../conf/desktop/fuzzel/fuzzel.ini;
  xdg.configFile."gtk-3.0/settings.ini".source = ../../conf/desktop/gtk-3.0/settings.ini;
  xdg.configFile."mimeapps.list".source = ../../conf/desktop/mimeapps.list;
  # Gruvbox theme (matches kitty.conf's palette) - rofi reads this
  # automatically with no -theme flag needed, so it covers pinentry-rofi and
  # rofi-bluetooth alike, not just one or the other.
  xdg.configFile."rofi/config.rasi".source = ../../conf/desktop/rofi/config.rasi;

  # discord/neomutt/scli/signal-desktop/visidata/vivaldi-stable .desktop
  # entries were dropped - none of those apps are installed by this flake,
  # and their Exec= lines hardcoded /usr/bin/* paths that don't exist on
  # NixOS anyway. vivaldi itself is still installed (desktop.nix) and ships
  # its own working .desktop file via the package.
  xdg.dataFile = {
    "applications/browser.desktop".source = ../../conf/desktop/share/applications/browser.desktop;
    "applications/nvim.desktop".source = ../../conf/desktop/share/applications/nvim.desktop;
  };

  systemd.user.services.swaync = {
    Unit = {
      Description = "Sway Notification Center";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service.ExecStart = "${pkgs.swaynotificationcenter}/bin/swaync";
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.udiskie = {
    Unit = {
      Description = "Automatically mount newly inserted USB drives";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    # --tray replaces the AUR udiskie-dmenu-git tray helper (not packaged in nixpkgs)
    Service.ExecStart = "${pkgs.udiskie}/bin/udiskie --tray";
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.systembus-notify = {
    Unit = {
      Description = "Show desktop notifications for earlyoom";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service.ExecStart = "${pkgs.systembus-notify}/bin/systembus-notify -q";
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.wl-clipboard-manager = {
    Unit = {
      Description = "Clipboard manager daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.couldinho-desktop-scripts}/bin/wl-clipboard-manager daemon";
      Restart = "always";
      RestartSec = "10s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.yubikey-touch-detector = {
    Unit = {
      Description = "Detect when YubiKey is waiting for a touch";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service.ExecStart = "${pkgs.yubikey-touch-detector}/bin/yubikey-touch-detector --libnotify";
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
