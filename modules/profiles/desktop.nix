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
  programs.zsh.loginShellInit = builtins.readFile ../../conf/desktop/zsh/zprofile;

  # No display manager - sway is launched from the zprofile on tty1, exactly
  # like the old system (which never used a DM either).
  services.getty.autologinUser = cfg.user;

  # Desktop notification on every ethernet/WiFi connect and disconnect -
  # in particular the automatic wifi<->ethernet switch when the USB hub is
  # plugged/unplugged, which nothing else here would otherwise surface.
  # nm-dispatcher-notify runs as root (NetworkManager's own dispatcher.d
  # convention) and needs the target user baked in to reach their session
  # bus - this wrapper is the only thing that knows cfg.user, so it sets
  # COULDINHO_USER and hands off to the real (host-agnostic) script.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "nm-dispatcher-notify-wrapper" ''
        export COULDINHO_USER="${cfg.user}"
        exec "${pkgs.couldinho-desktop-scripts}/bin/nm-dispatcher-notify" "$@"
      '';
    }
  ];
  # nmcli/notify-send aren't in NetworkManager-dispatcher's own default PATH
  # (just iproute2/util-linux/coreutils, see nixpkgs' networkmanager.nix) -
  # nm-dispatcher-notify needs both.
  systemd.services.NetworkManager-dispatcher.path = [ pkgs.networkmanager pkgs.libnotify ];

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
    ../../conf/desktop/X11/xorg.conf.d/00-keyboard.conf;
  # The us-hyper symbols file registered as an XKB layout, for use in sway's
  # `input * xkb_layout` / the above xorg.conf.d keyboard options.
  services.xserver.xkb.extraLayouts."us-hyper" = {
    description = "US layout with Hyper on CapsLock";
    languages = [ "eng" ];
    symbolsFile = ../../conf/base/xkb/symbols/us-hyper;
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
    # Confirmed live: XCURSOR_THEME was unset entirely, so sway couldn't
    # resolve a real theme (only Adwaita/hicolor are installed - no theme
    # named "default") and silently fell back to wlroots' own built-in
    # cursor, which rendered tiny regardless of XCURSOR_SIZE - that was the
    # actual "too small" cause, not the size value. Setting the theme
    # explicitly is what makes a real cursor (and XCURSOR_SIZE) apply at
    # all. gtk-3.0/settings.ini already names Adwaita for GTK apps' own
    # cursor; this matches it for sway's compositor-drawn one. Plain 24 -
    # sway multiplies this by the output's scale factor (2.0 on this
    # display) automatically, so 48 here actually rendered at 96 physical
    # pixels, confirmed live to be too big; 24 lands at the intended 48.
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
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
    # Confirmed via fonttools cmap inspection: the vendored Inconsolata Nerd
    # Font below only patched in the power-symbol range (U+23FB-U+23FE) plus
    # a handful of PUA icon ranges - it has neither the Unicode Miscellaneous
    # Technical media-control block (U+23E9-U+23FA, e.g. the ⏵⏵ Claude Code
    # renders for its permission-mode indicator) nor box-drawing (U+2500+) nor
    # en/em dash (U+2013/U+2014), and neither does nerd-fonts.symbols-only.
    # Those were silently falling back to NixOS's default proportional
    # DejaVu Sans fallback (dashes/box-drawing: present but off-metric,
    # rendering as faint/blank-looking in a monospace grid) or to nothing at
    # all (media-control block: tofu). unifont is a single, purpose-built,
    # fixed-width "don't show tofu" fallback font covering nearly the entire
    # BMP, including all of the above - a better fit here than pulling in
    # e.g. all of noto-fonts (50M, mostly unneeded non-Latin scripts) just
    # for one missing Unicode block.
    unifont
  ] ++ [
    (pkgs.runCommand "couldinho-desktop-fonts" { } ''
      mkdir -p $out/share/fonts
      cp "${../../conf/desktop/share/fonts}/Inconsolata Nerd Font Complete Mono.otf" "$out/share/fonts/"
      cp "${../../conf/desktop/share/fonts}/taskbar.ttf" "$out/share/fonts/"
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
    # Just the CLI tools (pactl et al) against PipeWire's pulse-compat
    # socket - services.pulseaudio.enable stays false, PipeWire owns the
    # actual daemon. sway-audio (volume/mute/bluetooth-profile keybindings)
    # calls pactl directly and had no provider for it at all - confirmed on
    # real hardware, "command not found" on every volume/brightness-row key.
    pulseaudio
    vimiv-qt # was vimiv
    feh
    imagemagick
    wf-recorder
    zathura
    zathuraPkgs.zathura_pdf_mupdf
    anki
    freerdp
    python3Packages.pillow
    # Were all missing entirely - each broke a live keybinding/service:
    playerctl # media keys + sway-exit's pause-before-lock (both call playerctl/playerctld)
    ffmpeg # sway-gif-area's mkv->gif encoding step
    sqlite # provides the sqlite3 binary - wl-clipboard-manager's history db, confirmed on real hardware,
            # its systemd service was running and failing this exact way on
            # every clipboard copy: "sqlite3: command not found"
    file # wl-clipboard-manager's MIME-type detection - same live failure
    nwg-displays # GUI for arranging monitor position/scale/rotation under sway

    # web
    vivaldi
    vivaldi-ffmpeg-codecs
    widevine-cdm # was vivaldi-widevine
    browserpass # was browserpass-chromium

    couldinho-desktop-scripts
  ];

  environment.etc."xdg/nvim".source = ../../conf/base/nvim; # kept for root/system-wide nvim invocations
}
