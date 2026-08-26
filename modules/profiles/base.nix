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
    loginShellInit = lib.mkDefault (builtins.readFile ../../conf/base/etc/zsh/zprofile);
    # was /etc/zsh/couldinho-zshrc -> /etc/zsh/zshrc. The old zshrc bootstrapped
    # zsh4humans, a framework that self-installs by curling a script from
    # GitHub on every machine's first shell start (envExtra/zshenv was 100%
    # that bootstrap and is gone entirely now). Replaced below by nixpkgs
    # packages - fetched and pinned at build time, not at shell-startup time -
    # for the same prompt and plugins.
    interactiveShellInit = builtins.readFile ../../conf/base/etc/zsh/zshrc + ''

      # Prompt (was zsh4humans' bundled powerlevel10k)
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      source /etc/zsh/p10k.zsh
    '';
  };
  # Autosuggestions + syntax highlighting (was zsh4humans' bundled
  # zsh-autosuggestions / zsh-syntax-highlighting) - both are native NixOS
  # module options, so no manual plugin sourcing is needed for these two.
  programs.zsh.autosuggestions.enable = true;
  programs.zsh.syntaxHighlighting.enable = true;
  environment.etc."zsh/zsh-aliases".source = ../../conf/base/etc/zsh/zsh-aliases;
  environment.etc."zsh/p10k.zsh".source = ../../conf/base/etc/zsh/p10k.zsh;
  environment.shells = [ pkgs.zsh ];
  environment.pathsToLink = [ "/share/zsh" ];

  environment.etc."gitconfig".source = ../../conf/base/etc/gitconfig;
  environment.etc."vimrc".source = ../../conf/base/etc/vimrc;
  environment.etc."htoprc".source = ../../conf/base/etc/htoprc;
  environment.etc."bat/config".source = ../../conf/base/etc/bat/conf;
  environment.etc."private-internet-access/pia.conf".source =
    ../../conf/base/etc/private-internet-access/pia.conf;

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

  console.keyMap = "us";
  console.useXkbConfig = true;

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
  };

  # --- YubiKey touch-to-confirm for sudo/polkit (was pam.d/{sudo,polkit-1}) ---
  security.pam.u2f = {
    enable = true;
    cue = true;
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
  services.snapper.configs.root = {
    subvolume = "/";
    extraConfig = ''
      ALLOW_USERS=""
      ALLOW_GROUPS=""
      SYNC_ACL="no"
      SPACE_LIMIT="0.5"
      BACKGROUND_COMPARISON="yes"
      NUMBER_CLEANUP="yes"
      NUMBER_MIN_AGE="1800"
      NUMBER_LIMIT="50"
      NUMBER_LIMIT_IMPORTANT="10"
      TIMELINE_CREATE="no"
      TIMELINE_CLEANUP="no"
      EMPTY_PRE_POST_CLEANUP="yes"
      EMPTY_PRE_POST_MIN_AGE="1800"
    '';
  };

  # /home is its own btrfs subvolume (disko.nix) and wasn't covered by the old
  # root-only snapper config - added here, same settings as root, so home
  # directory changes get the same manual/scheduled snapshot coverage.
  services.snapper.configs.home = {
    subvolume = "/home";
    extraConfig = ''
      ALLOW_USERS=""
      ALLOW_GROUPS=""
      SYNC_ACL="no"
      SPACE_LIMIT="0.5"
      BACKGROUND_COMPARISON="yes"
      NUMBER_CLEANUP="yes"
      NUMBER_MIN_AGE="1800"
      NUMBER_LIMIT="50"
      NUMBER_LIMIT_IMPORTANT="10"
      TIMELINE_CREATE="no"
      TIMELINE_CLEANUP="no"
      EMPTY_PRE_POST_CLEANUP="yes"
      EMPTY_PRE_POST_MIN_AGE="1800"
    '';
  };

  # --- Packages ---
  # NB: reflector (pacman mirror-list refresh) has no meaning under Nix -
  # binary cache substituters replace the concept of pacman mirrors entirely,
  # so it's dropped rather than mapped. urlwatch is retained below.
  environment.systemPackages = with pkgs; [
    git
    delta # was git-delta
    cifs-utils
    neovim
    nodejs
    fwupd

    # Base replacements
    eza
    ripgrep
    ripgrep-all
    bat
    htop
    lscolors # was lscolors-git
    dfrs

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
