# Everything from pkg/PKGBUILD's package_couldinho-dev() + .install.
{ config, lib, pkgs, ... }:
let
  cfg = config.couldinho;
in
{
  users.users.${cfg.user}.extraGroups = [ "docker" "libvirtd" "adbusers" ];

  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  programs.adb.enable = true;

  environment.systemPackages = with pkgs; [
    docker-compose
    docker-buildx
    docker-credential-helpers # provides docker-credential-pass
    rustup
    nasm
    python3Packages.ipython

    lld
    clang

    gdb
    rr

    awscli2 # was aws-cli-v2-bin
    aws-sam-cli # was aws-sam-cli-bin
    # was npm -> bundled in nodejs, already installed unconditionally by base.nix

    android-studio
  ];
}
