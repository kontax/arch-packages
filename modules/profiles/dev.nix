# Everything from pkg/PKGBUILD's package_couldinho-dev() + .install.
{ config, lib, pkgs, ... }:
let
  cfg = config.couldinho;
in
{
  # "adbusers" dropped along with programs.adb.enable - systemd handles the
  # udev/uaccess rules automatically now, no group membership needed
  users.users.${cfg.user}.extraGroups = [ "docker" "libvirtd" ];

  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  environment.systemPackages = with pkgs; [
    docker-compose
    docker-buildx
    docker-credential-helpers # provides docker-credential-pass
    rustup
    nasm
    python3Packages.ipython

    # was programs.adb.enable - option removed, systemd 258 handles uaccess
    # rules automatically now; this just gets the `adb` binary itself
    android-tools

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
