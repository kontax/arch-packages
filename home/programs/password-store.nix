# Clones/updates the personal `pass` store and writes the pass-git-helper
# mapping that tells git which pass entry backs which remote host - both
# personal information that doesn't belong hardcoded in this public repo,
# set via ~/.config/couldinho/local.nix instead (see local.nix.example,
# same reasoning as gpg-import.nix). Getting the encrypted files and the
# routing config in place doesn't get you anything readable on its own -
# decrypting any of it still needs the GPG secret key from gpg-import.nix,
# physically present on a YubiKey for this setup.
{ osConfig, lib, pkgs, ... }:
let
  cfg = osConfig.couldinho.passwordStore;
in
lib.mkMerge [
  (lib.mkIf (cfg.mapping != null) {
    home.file.".config/pass-git-helper/git-pass-mapping.ini".text = cfg.mapping;
  })

  (lib.mkIf (cfg.url != null) {
    # Not fatal on failure - this repo also targets machines (VMs,
    # freshly-bootstrapped hosts) with no network path to a personal git
    # server and no YubiKey to auth with yet, and a failed activation
    # script would otherwise break every rebuild until that's sorted.
    home.activation.clonePasswordStore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # This runs under home-manager-james.service's much narrower systemd
      # PATH (coreutils/findutils/gnugrep/gnused/systemd only), which
      # doesn't include openssh - a bare `ssh` on the git subprocess's PATH
      # fails with "error: cannot run ssh: No such file or directory" /
      # "fatal: unable to fork", the same failure shape as the bare awk in
      # gpg-import.nix. Qualify it explicitly via GIT_SSH_COMMAND rather
      # than relying on whatever's reachable.
      # accept-new: this is the very first SSH connection to this host from
      # a freshly-bootstrapped machine, so there's no known_hosts entry yet.
      # Interactive ssh would just prompt "are you sure? (yes/no)" here, but
      # there's no tty to ask from activation - confirmed on real hardware,
      # it fell through to trying $SSH_ASKPASS (unset, another dead end)
      # then gave up with "Host key verification failed." TOFU-trusting a
      # personal server the user already hardcoded themselves in local.nix
      # is the same trust decision an interactive "yes" would make; unlike
      # StrictHostKeyChecking=no, accept-new still fails on a *later* key
      # change for an already-known host, so this doesn't blind a real
      # MITM after the first successful clone.
      export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=accept-new"
      # Same narrow-service-environment problem for SSH_AUTH_SOCK: the auth
      # here is the YubiKey's Authenticate subkey via gpg-agent's SSH support
      # (gpg-import.nix), whose socket path is normally exported by
      # environment.extraInit for interactive shells - this activation
      # script isn't one, so resolve it the same way extraInit does.
      export SSH_AUTH_SOCK="''${SSH_AUTH_SOCK:-$(${pkgs.gnupg}/bin/gpgconf --list-dirs agent-ssh-socket)}"
      if [ -d "$HOME/.password-store/.git" ]; then
        $DRY_RUN_CMD ${pkgs.git}/bin/git -C "$HOME/.password-store" pull --ff-only ||
          echo "warning: couldn't update ~/.password-store" >&2
      else
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone "${cfg.url}" "$HOME/.password-store" ||
          echo "warning: couldn't clone ~/.password-store from ${cfg.url}" >&2
      fi
    '';
  })
]
