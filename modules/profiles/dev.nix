# Everything from pkg/PKGBUILD's package_couldinho-dev() + .install.
{ config, lib, pkgs, ... }:
let
  cfg = config.couldinho;
in
{
  # "adbusers" dropped along with programs.adb.enable - systemd handles the
  # udev/uaccess rules automatically now, no group membership needed.
  # "libvirtd" also dropped along with virtualisation.libvirtd/virt-manager
  # below - not used, and the legacy libvirtd.service was a persistently
  # failed unit for no functional benefit.
  users.users.${cfg.user}.extraGroups = [ "docker" ];

  virtualisation.docker.enable = true;

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

    claude-code # unverified attr name - nixpkgs wraps @anthropic-ai/claude-code

    gh # GitHub CLI - creating/managing PRs from a terminal

    age
    sops
    mkdocs
    terraform
  ];
}
