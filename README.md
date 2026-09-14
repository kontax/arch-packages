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
- `hosts/<name>/` - one machine each: disk layout (`disko.nix`),
  hardware-specific kernel config (`hardware-configuration.nix`, regenerate
  with `nixos-generate-config`), and which profiles it composes. `desktop`
  and `laptop` are real-hardware templates (`hardware-configuration.nix` is
  a placeholder until you regenerate it on the actual machine); `desktop-vm`
  is a Proxmox VM used to develop/test the `desktop` host's config before
  ever touching real hardware with it - see its own comments for what's
  VM-specific.
- `modules/profiles/*.nix` - one file per old package group
  (base/desktop/laptop/dev), each pulling in the same packages and config the
  equivalent `couldinho-*` pacman package used to.
- `home/` - home-manager config for the primary user's apps (sway, waybar,
  kitty, mpv, nvim), imported by the profile modules above.
- `pkgs/` - the overlay: bundles the `conf/*/bin` scripts verbatim into
  per-profile packages.
- `conf/` - the actual config file content, vendored byte-for-byte rather
  than rewritten. Organized by app (`conf/desktop/waybar/config`, etc.)
  rather than mirroring the old Arch filesystem paths those files used to
  install to - meaningless once Nix just symlinks files by explicit path.

## Installing on a new machine

1. Boot a NixOS installer ISO with networking.
2. Clone this repo (`git clone --recurse-submodules <url>` - the nvim config
   is a submodule).
3. `sudo ./bootstrap.sh <host> <disk>`, e.g. `sudo ./bootstrap.sh desktop /dev/nvme0n1`.
   This partitions the disk with disko, generates the hardware config, runs
   `nixos-install`, sets root's and the primary user's passwords, sets up
   Secure Boot signing keys and installs the bootloader (if the host has
   `couldinho.secureBoot` enabled - see `modules/secure-boot.nix`), and
   optionally enrolls a YubiKey for LUKS unlock. **This wipes the target
   disk.** All of this happens before you ever reboot into the new system -
   if Secure Boot key setup fails partway through (usually because the
   firmware isn't in "Setup Mode" yet), the script stops with instructions
   for retrying it from the still-live installer, since a machine with no
   bootloader installed can't boot at all.
4. Reboot. If you skipped Secure Boot or YubiKey enrollment above, or need
   to redo either one, see the comments in `modules/secure-boot.nix` and
   `modules/luks-common.nix` for the exact commands.

## Day to day

The `?submodules=1` is required, not optional - the nvim config
(`conf/base/nvim`) is a git submodule, and Nix's git-tree filtering ignores
submodule content unless you ask for it; without this flag you'll hit
`Path '...nvim' ... is not tracked by Git`.

`--impure` is required too - `~/.config/couldinho/local.nix` (personal
values that don't belong in this public repo, see `local.nix.example`)
lives outside the repo on purpose, and reading it needs `$HOME` via
`builtins.getEnv`, which only works in impure evaluation.

```bash
nix flake check '.?submodules=1' --impure
sudo nixos-rebuild switch --flake '.?submodules=1#desktop' --impure   # or #laptop / #desktop-vm
nix flake update                                                      # bump pinned inputs
```

## Adding a new host

Copy `hosts/desktop` to `hosts/<name>`, adjust `disko.nix`'s disk device,
regenerate `hardware-configuration.nix` on the real hardware, list the
profiles it needs in `default.nix`, and add it to `flake.nix`'s
`nixosConfigurations`.

## Adding a new package

1. **Find the exact attribute name.** Don't guess - a plausible-looking name
   can be wrong, or collide with something similarly named but different
   (e.g. `antigravity-cli` is a TUI agent client, not the `antigravity` GUI
   IDE; `browserpass` is just a native-messaging binary with no browser
   integration until `programs.browserpass.enable` is also set). Search
   locally, without touching the network:
   ```bash
   nix-env -f '<nixpkgs>' -qaP --description | grep -i <name>
   ```
   or use [search.nixos.org/packages](https://search.nixos.org/packages).
   If more than one result looks plausible, check each one's
   `meta.mainProgram` and `meta.description` before picking:
   ```bash
   nix eval --impure --json --expr '(import <nixpkgs> {}).<attr>.meta' | jq
   ```
2. **Pick the right file.** `modules/profiles/base.nix` for anything wanted
   on every host, `dev.nix`/`desktop.nix`/`laptop.nix` for profile-specific
   tools (GUI apps go in `desktop.nix` even though CLI tools also live
   there - see `android-studio` next to `claude-code` in `dev.nix`).
3. **Add it** to that file's `environment.systemPackages` list (alphabetical
   isn't enforced - match the existing grouping/comments in that section).
   Add a one-line comment only if the attribute name is non-obvious, unfree,
   or the binary name doesn't match the attribute name.
4. **Validate before changing anything live:**
   ```bash
   nix flake check '.?submodules=1' --impure
   ```
   This catches eval errors (typo'd attribute names, missing
   `nixpkgs.config.allowUnfree`/`allowUnfreePackages`, etc.) without
   building or touching the running system.
5. **Rebuild and switch:**
   ```bash
   sudo nixos-rebuild switch --flake '.?submodules=1#<host>' --impure
   ```
6. **Test it live, don't just trust the build.** A successful rebuild only
   means the derivation built - it says nothing about whether the command
   you expect actually exists or works. Run the real binary (check
   `meta.mainProgram` from step 1 if the name isn't obvious, e.g.
   `antigravity-cli`'s binary is `agy`), and for anything with a config
   surface (a systemd unit, a NixOS module `enable` option, a generated
   `/etc` file), check the actual live state - don't assume the option name
   alone was enough.
7. **Commit and push** once confirmed working.

## Sources
* [Disconnected's guide](https://disconnected.systems/blog/archlinux-repo-in-aws-bucket/)
* [Maxim Baz's dotfiles](https://github.com/maximbaz/dotfiles.git)
