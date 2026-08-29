# Everything from pkg/PKGBUILD's package_couldinho-base() + couldinho-base.install.
# Included on every host.
{ config, lib, pkgs, ... }:
let
  cfg = config.couldinho;
in
{
  # --- User (was `useradd -m -s /usr/bin/zsh -g users -G wheel,uucp,video,audio,storage,games,input`) ---
  # No password is set here on purpose - run `passwd` for both root and
  # ${cfg.user} after the first boot, same as the old installer's interactive
  # password prompt but without committing any secret to this repo.
  users.mutableUsers = true;
  users.users.${cfg.user} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "uucp" "video" "audio" "storage" "input" "networkmanager" ];
  };

  # --- Shell (zshrc/aliases/p10k, sourced by absolute /etc/zsh paths from
  # within zshrc itself, so those two extra files are kept at the same
  # literal paths rather than moved into home-manager) ---
  programs.zsh = {
    enable = true;
    # was /etc/zsh/couldinho-zprofile -> /etc/zsh/zprofile (desktop profile overrides this).
    # Also now carries the PATH prepend from base/etc/environment.d/30-path.conf
    # (see comment in that vendored file) rather than environment.sessionVariables.PATH,
    # since NixOS renders sessionVariables as literal `export VAR="..."` assignments -
    # a list there would *replace* PATH instead of extending it.
    loginShellInit = lib.mkDefault (builtins.readFile ../../conf/base/zsh/zprofile);
    # was /etc/zsh/couldinho-zshrc -> /etc/zsh/zshrc. The old zshrc bootstrapped
    # zsh4humans, a framework that self-installs by curling a script from
    # GitHub on every machine's first shell start (envExtra/zshenv was 100%
    # that bootstrap and is gone entirely now). Replaced below by nixpkgs
    # packages - fetched and pinned at build time, not at shell-startup time -
    # for the same prompt and plugins.
    interactiveShellInit = builtins.readFile ../../conf/base/zsh/zshrc + ''

      # Prompt (was zsh4humans' bundled powerlevel10k). The vendored p10k.zsh
      # was generated years ago against whatever p10k version zsh4humans
      # bundled at the time - nixpkgs' current zsh-powerlevel10k doesn't
      # recognize it as "already configured" (version/checksum mismatch) and
      # offers to run the setup wizard on every new shell. The config itself
      # still applies correctly regardless - this just silences the nag.
      typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      source /etc/zsh/p10k.zsh
    '';
  };
  # Autosuggestions + syntax highlighting (was zsh4humans' bundled
  # zsh-autosuggestions / zsh-syntax-highlighting) - both are native NixOS
  # module options, so no manual plugin sourcing is needed for these two.
  programs.zsh.autosuggestions.enable = true;
  programs.zsh.syntaxHighlighting.enable = true;
  environment.etc."zsh/zsh-aliases".source = ../../conf/base/zsh/zsh-aliases;
  environment.etc."zsh/p10k.zsh".source = ../../conf/base/zsh/p10k.zsh;
  environment.shells = [ pkgs.zsh ];
  environment.pathsToLink = [ "/share/zsh" ];

  environment.etc."gitconfig".source = ../../conf/base/gitconfig;
  environment.etc."vimrc".source = ../../conf/base/vimrc;
  environment.etc."htoprc".source = ../../conf/base/htoprc;
  environment.etc."bat/config".source = ../../conf/base/bat/conf;

  # --- Locale / time (was the locale.gen / locale.conf / localtime steps in install.sh) ---
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "en_IE.UTF-8/UTF-8" ];
  i18n.extraLocaleSettings = {
    LANGUAGE = "en_US";
    LC_MONETARY = "en_IE.UTF-8";
    LC_TIME = "en_IE.UTF-8";
  };
  time.timeZone = "Europe/Dublin";

  environment.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    BAT_THEME = "gruvbox-dark";
    DIFFPROG = "vimdiff";
    PASSWORD_STORE_CHARACTER_SET = "a-zA-Z0-9~!@#$%^&*()-_=+[]{};:,.<>?";
    PASSWORD_STORE_GENERATED_LENGTH = "40";

    # was base/etc/environment.d/40-clean-home.conf - kept $HOME-relative
    # (rather than chaining off $XDG_*_HOME, which desktop.nix also sets) since
    # NixOS renders all sessionVariables into one flat shell script and the
    # cross-module ordering between the two isn't guaranteed; these already
    # match the XDG defaults desktop.nix sets explicitly.
    DOCKER_CONFIG = "$HOME/.config/docker";
    PYLINTRC = "$HOME/.config/pylint/config";
    CARGO_HOME = "$HOME/.local/state/cargo";
    PYLINTHOME = "$HOME/.cache/pylint";
    LESSHISTFILE = "-";
  };

  console.font = lib.mkDefault "ter-v16n"; # was FONT=ter-132n/ter-716n (hidpi choice), override per-host
  console.packages = [ pkgs.terminus_font ];

  # Plain "us" TTY keymap - the original Arch vconsole.conf never set KEYMAP
  # at all (so this is just an explicit version of its default), and was
  # never tied to the desktop profile's custom X11/Wayland "jc"/hyper layout,
  # which is GUI-only. console.useXkbConfig would derive this keymap from
  # that X11 config instead, which conflicts with a plain string here - only
  # set one or the other.
  console.keyMap = "us";

  # --- SSH (not in the original Arch setup - added for remote access;
  # openFirewall defaults to true, so port 22 opens automatically. Password
  # auth is left on since no authorized_keys are set up anywhere in this repo
  # yet - lock it down with users.users.${cfg.user}.openssh.authorizedKeys.keys
  # + services.openssh.settings.PasswordAuthentication = false once you have
  # a key you want to use.) ---
  services.openssh.enable = true;

  # --- Networking + VPN ---
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = with pkgs; [
    networkmanager-openvpn
    networkmanager-strongswan
  ];

  # --- USBGuard (was base/etc/usbguard/usbguard-daemon.conf) ---
  services.usbguard = {
    enable = true;
    implicitPolicyTarget = "block";
    presentDevicePolicy = "apply-policy";
    presentControllerPolicy = "apply-policy";
    IPCAllowedUsers = [ "root" cfg.user ];
  };

  # --- earlyoom (was base/etc/default/earlyoom: EARLYOOM_ARGS="-r 3600 -n --avoid '^(systemd|sshd|sway|waybar)$'") ---
  services.earlyoom = {
    enable = true;
    reportInterval = 3600;
    enableNotifications = true;
    extraArgs = [ "--avoid" "^(systemd|sshd|sway|waybar)$" ];
  };

  # --- gpg-agent as SSH agent (zprofile exports SSH_AUTH_SOCK pointing at
  # $XDG_RUNTIME_DIR/gnupg/S.gpg-agent.ssh - that socket only exists with
  # enableSSHSupport on) ---
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # Left unset, this defaults to picking pinentry-gnome3 (the module's
    # auto-detect heuristic falls back to "gnome3 on all other systems with
    # X enabled" - true here even under sway, since services.xserver.enable
    # is on for xkb keyboard config). Its GTK dialog doesn't reliably grab
    # keyboard focus outside an actual GNOME session under wlroots
    # compositors - confirmed on real hardware, the PIN prompt appeared but
    # couldn't be typed into. pinentry-rofi uses the same rofi launcher
    # already relied on elsewhere in this sway setup (dmenu-nmcli,
    # rofi-bluetooth), so it gets the same reliable focus every other rofi
    # menu already has.
    pinentryPackage = pkgs.pinentry-rofi;
  };

  # --- YubiKey touch-to-confirm for sudo/polkit (was pam.d/{sudo,polkit-1}) ---
  security.pam.u2f = {
    enable = true;
    settings.cue = true; # was top-level `cue` - renamed under settings.*
    settings.cue_prompt = "Please touch YubiKey to confirm the action.";
  };
  security.pam.services.sudo.u2fAuth = true;
  security.pam.services.polkit-1.u2fAuth = true;

  # --- sudoers (was base/etc/sudoers: wheel + NOPASSWD stop of pcscd.service) ---
  security.sudo.extraRules = [{
    groups = [ "wheel" ];
    commands = [{
      command = "/run/current-system/sw/bin/systemctl stop pcscd.service";
      options = [ "NOPASSWD" "SETENV" ];
    }];
  }];

  # --- Snapper (was base/etc/snapper/configs/root + base/etc/conf.d/snapper) ---
  # NB: snap-pac's automatic pre/post-pacman-transaction snapshots have no NixOS
  # equivalent (system config changes are already tracked via NixOS generations);
  # this config only covers manual/scheduled snapshots of /. See MIGRATION.md.
  # subvolume -> SUBVOLUME and extraConfig -> direct attributes: both renames
  # nixpkgs made to services.snapper.configs.* since this was first written.
  # The rework also gave each field its natural Nix type instead of treating
  # everything as a raw config-file string - lists for the space-separated
  # user/group fields, bools for the yes/no flags, ints for the numeric
  # limits/ages. Values themselves are unchanged from the original
  # base/etc/snapper/configs/root.
  services.snapper.configs.root = {
    SUBVOLUME = "/";
    ALLOW_USERS = [ ];
    ALLOW_GROUPS = [ ];
    SYNC_ACL = false;
    SPACE_LIMIT = 0.5;
    # true (the original value) makes snapper-cleanup pre-compute a diff
    # between snapshots asynchronously via snapperd's D-Bus service - NixOS's
    # services.snapper module doesn't wire up snapperd's D-Bus registration,
    # so that call hangs for the D-Bus timeout and fails the whole cleanup
    # unit (org.freedesktop.DBus.Error.NameHasNoOwner, ~90s wall clock with
    # ~0 CPU time - a blocked/timed-out IPC call, not an actual crash).
    # Cleanup and snapshotting themselves don't need this, so it's disabled.
    BACKGROUND_COMPARISON = false;
    NUMBER_CLEANUP = true;
    NUMBER_MIN_AGE = 1800;
    NUMBER_LIMIT = 50;
    NUMBER_LIMIT_IMPORTANT = 10;
    TIMELINE_CREATE = false;
    TIMELINE_CLEANUP = false;
    EMPTY_PRE_POST_CLEANUP = true;
    EMPTY_PRE_POST_MIN_AGE = 1800;
  };

  # /home is its own btrfs subvolume (disko.nix) and wasn't covered by the old
  # root-only snapper config - added here, same settings as root, so home
  # directory changes get the same manual/scheduled snapshot coverage.
  services.snapper.configs.home = {
    SUBVOLUME = "/home";
    ALLOW_USERS = [ ];
    ALLOW_GROUPS = [ ];
    SYNC_ACL = false;
    SPACE_LIMIT = 0.5;
    BACKGROUND_COMPARISON = false; # see the comment on the root config above
    NUMBER_CLEANUP = true;
    NUMBER_MIN_AGE = 1800;
    NUMBER_LIMIT = 50;
    NUMBER_LIMIT_IMPORTANT = 10;
    TIMELINE_CREATE = false;
    TIMELINE_CLEANUP = false;
    EMPTY_PRE_POST_CLEANUP = true;
    EMPTY_PRE_POST_MIN_AGE = 1800;
  };

  # --- Packages ---
  # NB: reflector (pacman mirror-list refresh) has no meaning under Nix -
  # binary cache substituters replace the concept of pacman mirrors entirely,
  # so it's dropped rather than mapped. urlwatch is retained below.
  environment.systemPackages = with pkgs; [
    git
    delta # was git-delta
    cifs-utils
    nfs-utils # mount.nfs/mount.nfs4 - was missing entirely, no NFS client support anywhere in this flake
    neovim
    nodejs
    # Was in couldinho-base's depends=(...), missed during the migration -
    # every other python3 reference in this flake (pkgs/default.nix's script
    # interpreters, nvim's pynvim, dev.nix's ipython, desktop.nix's i3ipc/
    # pillow) is a build-time dependency baked into one specific derivation,
    # not a general-purpose interpreter on PATH.
    python3
    fwupd

    # Base replacements
    eza
    ripgrep
    ripgrep-all
    fd
    bat
    htop
    lscolors # was lscolors-git
    dfrs
    psmisc # killall/fuser/pstree - not pulled in by anything on NixOS by default

    # Shell
    direnv
    tmux
    fzf
    fzy
    bash-completion

    # Filesystem
    btrfs-progs
    snapper
    zip
    unzip
    ncdu

    # Access control / security
    pass
    pass-git-helper
    pwgen
    yubikey-manager
    yubico-pam
    libu2f-server
    pam_u2f # was pam-u2f
    git-secret

    # Networking
    wireguard-tools
    openvpn
    socat
    speedtest-cli
    net-tools
    netcat-openbsd # was openbsd-netcat
    iw
    bandwhich
    croc

    # Misc
    urlwatch

    couldinho-base-scripts # was base/usr/local/bin/vimdiff
  ];

  services.timesyncd.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
}
