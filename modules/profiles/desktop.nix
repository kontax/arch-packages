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
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-wlr pkgs.xdg-desktop-portal-gtk ];
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

    LIBVA_DRIVER_NAME = "iHD";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland-egl";
    WLR_DRM_NO_MODIFIERS = "1";
    XDG_CURRENT_DESKTOP = "sway";
    XDG_SESSION_DESKTOP = "sway";
    XDG_SESSION_TYPE = "wayland";
  };

  # --- Fonts (vendored font files below are exact, no guessing needed) ---
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

  # --- Multimedia (PulseAudio, not Pipewire, matching the old setup) ---
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = false;
  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    # sway stack
    wl-clipboard
    python3Packages.i3ipc
    slurp
    grim
    swappy

    # apps / utilities
    alsa-utils
    alsa-plugins # was pulseaudio-alsa
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
