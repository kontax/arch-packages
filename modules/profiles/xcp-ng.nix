# Everything from pkg/PKGBUILD's package_couldinho-xcp-ng() + .install.
# XCP-NG/XenServer guest tools.
#
# NB: unlike the other profiles, this one isn't wired into any
# nixosConfiguration in flake.nix yet - add a host for it if/when needed.
{ pkgs, ... }:
{
  boot.kernelModules = [ "xen-blkfront" "xen-netfront" "xen-fbfront" ];

  environment.systemPackages = [ pkgs.xe-guest-utilities ];

  # Best-effort reproduction of the old xe-linux-distribution.service enable -
  # verify the ExecStart invocation against the actual nixpkgs package's
  # bin/ layout before relying on this (untested, no XCP-NG host wired up yet).
  systemd.services.xe-linux-distribution = {
    description = "Reports OS information to the XenServer/XCP-NG host";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.xe-guest-utilities}/bin/xe-linux-distribution /var/cache/xe-linux-distribution";
    };
  };
}
