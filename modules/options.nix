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
}
