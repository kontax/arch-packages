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

  # Personal information (a GPG key ID/URL, in this case) doesn't belong
  # hardcoded in this public repo. These are left unset here - set them in a
  # local.nix at the repo root (gitignored, see local.nix.example) if you
  # want home/programs/gpg-import.nix to actually import a key.
  options.couldinho.gpg.keyId = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "GPG key ID to import and trust, if set. See local.nix.example.";
  };

  options.couldinho.gpg.keyUrl = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "URL to fetch the public key from, if couldinho.gpg.keyId is set.";
  };
}
