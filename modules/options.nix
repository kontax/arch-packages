# Shared options referenced across profile modules, filled in per-host.
{ lib, ... }:
{
  options.couldinho.user = lib.mkOption {
    type = lib.types.str;
    description = ''
      Primary interactive user for this host - was the free-text `user`
      prompt in the old install.sh dialog wizard.
    '';
  };

  options.couldinho.secureBoot = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to use lanzaboote for Secure Boot (see modules/secure-boot.nix).
      Set false for VMs/test environments where Secure Boot doesn't add
      anything (the hypervisor already fully controls the guest) and can be
      finicky to enroll keys for depending on the virtual firmware - falls
      back to plain systemd-boot instead.
    '';
  };

  # Personal information (a GPG key ID, in this case) doesn't belong
  # hardcoded in this public repo. Left unset here - set it in
  # ~/.config/couldinho/local.nix (see local.nix.example) if you want
  # home/programs/gpg-import.nix to fetch it from a keyserver and set it as
  # ultimately trusted.
  options.couldinho.gpg.keyId = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "GPG key ID to mark as ultimately trusted, if set. See local.nix.example.";
  };

  # Same reasoning as couldinho.gpg.keyId above - the pass repo URL and the
  # pass-git-helper mapping (which pass entry backs which git remote) are
  # personal, not secret (the store itself is what's actually encrypted, and
  # reading it back out still needs the GPG secret key above to be present -
  # on a YubiKey for this setup, not just imported). See
  # home/programs/password-store.nix and local.nix.example.
  options.couldinho.passwordStore = {
    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Git URL to clone/pull as ~/.password-store, if set. See local.nix.example.";
    };

    mapping = lib.mkOption {
      type = lib.types.nullOr lib.types.lines;
      default = null;
      description = "Contents of ~/.config/pass-git-helper/git-pass-mapping.ini, if set. See local.nix.example.";
    };
  };
}
