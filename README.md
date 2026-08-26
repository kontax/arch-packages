# couldinho NixOS systems

A NixOS flake for my systems, tuned to my specific hardware and workflow -
this will overwrite anything already installed on an existing machine.

This used to be an Arch Linux pacman meta-package repo (`couldinho-base` /
`-desktop` / `-laptop` / `-dev`) with a from-scratch `dialog`-driven
installer. It's now a NixOS flake instead: see
[MIGRATION.md](MIGRATION.md) for how each old package/config maps onto this
new layout, and what didn't have a clean equivalent.

## Layout

- `flake.nix` - inputs (nixpkgs, home-manager, disko, lanzaboote) and the
  `nixosConfigurations` for each real machine.
- `hosts/<name>/` - one real machine each (`desktop`, `laptop`): disk layout
  (`disko.nix`), hardware-specific kernel config (`hardware-configuration.nix`,
  regenerate with `nixos-generate-config`), and which profiles it composes.
- `modules/profiles/*.nix` - one file per old package group
  (base/desktop/laptop/dev), each pulling in the same packages and config the
  equivalent `couldinho-*` pacman package used to.
- `home/` - home-manager config for the primary user's apps (sway, waybar,
  kitty, mpv, nvim), imported by the profile modules above.
- `pkgs/` - the overlay: bundles the old `conf/*/usr/local/bin` scripts
  verbatim into per-profile packages.
- `conf/` - unchanged: the actual config file content, vendored by the
  modules/home-manager files above rather than rewritten.

## Installing on a new machine

1. Boot a NixOS installer ISO with networking.
2. Clone this repo (`git clone --recurse-submodules <url>` - the nvim config
   is a submodule).
3. `sudo ./bootstrap.sh <host> <disk>`, e.g. `sudo ./bootstrap.sh desktop /dev/nvme0n1`.
   This partitions the disk with disko, generates the hardware config, and
   runs `nixos-install`. **This wipes the target disk.**
4. After first boot: set passwords (`passwd`), enroll Secure Boot keys, and
   enroll a YubiKey for LUKS if you use one - see the comments in
   `modules/secure-boot.nix` and `modules/luks-common.nix` for the exact
   commands.

## Day to day

```bash
sudo nixos-rebuild switch --flake .#desktop   # or #laptop
nix flake update                              # bump pinned inputs
```

## Adding a new host

Copy `hosts/desktop` to `hosts/<name>`, adjust `disko.nix`'s disk device,
regenerate `hardware-configuration.nix` on the real hardware, list the
profiles it needs in `default.nix`, and add it to `flake.nix`'s
`nixosConfigurations`.

## Sources
* [Disconnected's guide](https://disconnected.systems/blog/archlinux-repo-in-aws-bucket/)
* [Maxim Baz's dotfiles](https://github.com/maximbaz/dotfiles.git)
