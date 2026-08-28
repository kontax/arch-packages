# Everything from pkg/PKGBUILD's package_couldinho-desktop() + .install.
# Dual-monitor sway/Wayland desktop.
{ config, lib, pkgs, ... }:
let
  cfg = config.couldinho;
in
{
  # --- Home-manager: sway/waybar/kitty/mpv/nvim/etc, see home/home.nix ---
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${cfg.user}.imports = [ ../../home/home.nix ];

  # --- Desktop zprofile override (autostarts sway on tty1), replaces base's ---
  programs.zsh.loginShellInit = builtins.readFile ../../conf/desktop/etc/zsh/zprofile;

  # No display manager - sway is launched from the zprofile on tty1, exactly
  # like the old system (which never used a DM either).
  services.getty.autologinUser = cfg.user;

  security.polkit.enable = true;
  services.dbus.enable = true;
  # udiskie (home/programs/desktop.nix) is only the client - on Arch,
  # installing it pulls in udisks2 as a package dependency and D-Bus
  # activates the daemon automatically; under NixOS the daemon needs this
  # explicit enable, which was missing entirely (udiskie failed with a GDBus
  # error querying the Manager's Version property - nothing was answering).
  services.udisks2.enable = true;

  # Same story again, this time for swaync: it persists settings (DND state
  # included) via dconf/GSettings, and nothing registered dconf's D-Bus
  # service as activatable - confirmed on real hardware via swaync's own
  # journal: "failed to commit changes to dconf: ... ServiceUnknown: The
  # name is not activatable". Toggling DND appeared to apply (swaync-client
  # --toggle-dnd printed the new state) but reverted almost immediately -
  # the write silently failed and a subsequent read fell back to the old,
  # unpersisted value, which looked like the waybar icon "flashing" on
  # click. programs.dconf.enable wires up the missing D-Bus service.
  programs.dconf.enable = true;

  # On Arch, swaylock's package ships its own /etc/pam.d/swaylock
  # automatically; under NixOS nothing configures a PAM stack for it unless
  # declared explicitly. Without this, PAM has no module stack for the
  # "swaylock" service at all, so authentication just hangs/fails
  # indefinitely rather than accepting or rejecting a password - matches the
  # "locked out, can't unlock" symptom exactly. {} uses NixOS's standard
  # password-auth default, same as the original Arch package's stock config
  # (no yubikey touch requirement - that was never set up for swaylock
  # specifically, only sudo/polkit-1, see base.nix).
  security.pam.services.swaylock = { };
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-wlr pkgs.xdg-desktop-portal-gtk ];
    # xdg-desktop-portal >= 1.17 requires an explicit backend selection
    # instead of just picking the first one found - "*" keeps the old
    # (pre-1.17) behaviour of using whichever extraPortal matches first.
    config.common.default = "*";
  };

  # --- Backend (was xorg-xwayland/qt5-wayland/vulkan-intel/vulkan-headers) ---
  programs.xwayland.enable = true;
  qt.enable = true;
  qt.platformTheme = "gtk2";
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver vulkan-loader ];
  };

  environment.etc."X11/xorg.conf.d/00-keyboard.conf".source =
    ../../conf/desktop/etc/X11/xorg.conf.d/00-keyboard.conf;
  # The us-hyper symbols file registered as an XKB layout, for use in sway's
  # `input * xkb_layout` / the above xorg.conf.d keyboard options.
  services.xserver.xkb.extraLayouts."us-hyper" = {
    description = "US layout with Hyper on CapsLock";
    languages = [ "eng" ];
    symbolsFile = ../../conf/base/etc/xkb/symbols/us-hyper;
  };

  # --- Session env vars (was desktop/etc/environment.d/{20-xdg,60-wayland}.conf) ---
  environment.sessionVariables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";

    # gtk-3.0/settings.ini's gtk-theme-name alone isn't enough - confirmed
    # on real hardware, GTK3 apps (pavucontrol included) rendered as plain
    # default Adwaita, not even honoring settings.ini's own
    # gtk-application-prefer-dark-theme. No XSettings daemon or
    # xdg-desktop-portal runs under bare sway, and GTK3 falls back to
    # GSettings schema defaults ahead of settings.ini in that case rather
    # than actually reading it. GTK_THEME overrides both unconditionally -
    # confirmed working (GTK_THEME=Gruvbox-Dark pavucontrol rendered
    # correctly) where settings.ini alone did not.
    GTK_THEME = "Gruvbox-Dark";
    LIBVA_DRIVER_NAME = "iHD";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland-egl";
    WLR_DRM_NO_MODIFIERS = "1";
    XDG_CURRENT_DESKTOP = "sway";
    XDG_SESSION_DESKTOP = "sway";
    XDG_SESSION_TYPE = "wayland";
  };

  # --- Fonts (vendored font files below are exact, no guessing needed) ---
  # JoyPixels isn't covered by the blanket nixpkgs.config.allowUnfree in
  # base.nix - it needs its own explicit license acceptance.
  nixpkgs.config.allowUnfreePackages = [ "joypixels" ];
  nixpkgs.config.joypixels.acceptLicense = true;

  fonts.packages = with pkgs; [
    font-awesome # was otf-font-awesome
    joypixels # was ttf-joypixels
    nerd-fonts.symbols-only # was ttf-nerd-fonts-symbols[-mono]
  ] ++ [
    (pkgs.runCommand "couldinho-desktop-fonts" { } ''
      mkdir -p $out/share/fonts
      cp "${../../conf/desktop/usr/share/fonts}/Inconsolata Nerd Font Complete Mono.otf" "$out/share/fonts/"
      cp "${../../conf/desktop/usr/share/fonts}/taskbar.ttf" "$out/share/fonts/"
    '')
  ];

  # --- Multimedia (PipeWire, not the old system's raw PulseAudio - avoids
  # needing laptop.nix's old pulseaudioFull + module-switch-on-connect
  # workaround for bluetooth audio, which WirePlumber handles natively) ---
  services.pulseaudio.enable = false; # was hardware.pulseaudio.enable - renamed upstream
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # PulseAudio-protocol compat, used by pavucontrol/pamixer/waybar
    wireplumber.enable = true;
  };
  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    # sway stack
    wl-clipboard
    python3Packages.i3ipc
    slurp
    grim
    swappy

    # apps / utilities
    jq # used by waybar-updates to diff flake.lock
    alsa-utils
    pavucontrol
    pamixer
    vimiv-qt # was vimiv
    feh
    imagemagick
    wf-recorder
    zathura
    zathuraPkgs.zathura_pdf_mupdf
    anki
    freerdp
    python3Packages.pillow

    # web
    vivaldi
    vivaldi-ffmpeg-codecs
    widevine-cdm # was vivaldi-widevine
    browserpass # was browserpass-chromium

    couldinho-desktop-scripts
  ];

  environment.etc."xdg/nvim".source = ../../conf/base/etc/xdg/nvim; # kept for root/system-wide nvim invocations
}
