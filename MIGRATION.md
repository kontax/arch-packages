# Migration notes: Arch pacman packages -> NixOS flake

This documents how every `depends=(...)` entry and `install -Dm ...` line from
the old `pkg/PKGBUILD` maps onto the new flake, and what didn't map cleanly.
Package names were checked against the live nixpkgs-unstable index behind
search.nixos.org (not just memory), but this session still has no `nix`
binary available to actually run `nix flake check`/`nixos-rebuild build`
(Windows/Git Bash only) - do that on a real Linux box before relying on this.

## Intentionally dropped (no NixOS equivalent needed)

Arch/pacman-mechanism packages with no meaning under Nix, not functionality
gaps:
- `pacman`, `pacman-contrib`, `devtools`, `aurutils-git`, `arch-audit`,
  `rebuild-detector`, `reflector` - pacman/AUR package-management tooling.
  Nix's binary cache substituters + `nix flake update` + NixOS generations
  replace the concept entirely.
- `sbctl` standalone workflow, `cryptboot`, `mkinitcpio-encrypt-detached-header`
  - replaced by `lanzaboote` (`modules/secure-boot.nix`) and disko/systemd
    native LUKS+header support (`modules/luks-common.nix`).
- `stow` - dotfiles are now first-class Nix/home-manager config, not symlinked
  from a cloned repo.
- `base-devel` group and the `base`/`linux`/`filesystem`/etc. bootstrap group
  - a NixOS system already provides an equivalent minimal toolchain/base
    system; nothing to port.
- `pepper-flash` - Adobe Flash was discontinued in 2020; not carried forward.
- `snap-pac`'s auto-snapshot-around-every-pacman-transaction behaviour has no
  NixOS equivalent (confirmed: no nixpkgs package either). NixOS generations
  already give rollback for system config changes, which is what snap-pac
  covered for `/`. `services.snapper` is kept for general/manual snapshotting
  (`modules/profiles/base.nix`), but nothing auto-snapshots around
  `nixos-rebuild` the way snap-pac did around `pacman -Syu`.

## Confirmed gaps (no nixpkgs package - manual attention needed, not a Nix
## derivation Claude should fabricate an installer for)

| Package | Why it's a gap |
|---|---|
| `gtk-theme-arc-gruvbox-git` | Not packaged. Closest substitutes: `pkgs.gruvbox-gtk-theme` or `pkgs.gruvbox-dark-gtk` (different theme, not a drop-in) |
| `python-chump-git` (Pushover client for urlwatch) | Not packaged; urlwatch itself is kept, this notification backend is dropped |
| `udiskie-dmenu-git` | Not packaged; replaced with udiskie's own `--tray` flag (`home/programs/desktop.nix`) |
| `light` | Unpackaged fork; using `pkgs.acpilight` (maintained fork, slightly different CLI) instead - see `modules/profiles/laptop.nix` |
| `checkofficial` script | Calls pacman-contrib's `checkupdates`, which doesn't exist under NixOS - still installed verbatim (via `couldinho-desktop-scripts`) but non-functional |

The `sec` and `xcp-ng` profiles (reversing/exploitation tooling and XCP-NG
guest tools) were dropped entirely rather than migrated - not needed, so
their packages (radare2, ghidra, ida-free, burpsuite, gef/pwndbg/peda,
wireshark, aflplusplus, xe-guest-utilities, etc.) and gaps (010editor,
caido-desktop, binaryninja-free, pwndbg, peda, pwngdb, r2ghidra, afl-utils)
no longer apply.

`lscolors-git` and `dfrs` turned out **not** to be gaps - nixpkgs has
`pkgs.lscolors` and `pkgs.dfrs` directly, both used in `modules/profiles/base.nix`.

## Package name mapping (per profile, old name -> nixpkgs attribute)

Only entries that differ non-trivially from the old name are listed; anything
not here is used under the same/obvious name in the profile modules.

**base**: `git-delta`->`delta`, `pam-u2f`->`pam_u2f`, `openbsd-netcat`->`netcat-openbsd`.

**desktop**: `otf-font-awesome`->`font-awesome`, `ttf-joypixels`->`joypixels`
(custom license - covered by the global `nixpkgs.config.allowUnfree = true`,
double check on first build), `ttf-nerd-fonts-symbols[-mono]`->
`nerd-fonts.symbols-only` (nixpkgs restructured nerd-fonts into per-font attrs
- `ttf-inconsolata`'s nerd variant would be `nerd-fonts.inconsolata`, but
that's skipped since the exact font file is already vendored from
`conf/desktop/usr/share/fonts/`), `pinentry`->`pinentry-gnome3` (no bare
`pinentry` attr; `pinentry-gtk2` specifically is NOT packaged),
`pulseaudio-alsa`->N/A (desktop.nix uses PipeWire's own ALSA compat via
`services.pipewire.alsa.enable`, not a separate package), `vimiv`->`vimiv-qt` (GTK version removed
from nixpkgs, only the Qt port remains), `zathura-pdf-mupdf`->
`zathuraPkgs.zathura_pdf_mupdf`, `mpv-mpris`->`pkgs.mpvScripts.mpris` (ships
as an mpv script, not a binary - wired via `xdg.configFile` in
`home/programs/mpv.nix`, **output path not yet verified**), `swaync`->
`swaynotificationcenter` (binary is still called `swaync`), `vivaldi-widevine`
->`widevine-cdm`, `browserpass-chromium`->`browserpass`, `qt5-wayland`->
bundled via `qt.enable`, not added as a separate package, `vulkan-intel`->N/A
(bundled in `mesa`, exposed via `hardware.graphics.enable`), `bluez-utils`->N/A
(bundled in `pkgs.bluez`).

**laptop**: `light`->`acpilight` (see gaps table), `pulseaudio-bluetooth`->N/A
(desktop.nix uses PipeWire, not PulseAudio; WirePlumber handles bluetooth
output switching without any extra package or config), `sof-firmware`->
`pkgs.sof-firmware` via `hardware.firmware`.

**dev**: `aws-cli-v2-bin`->`awscli2`, `aws-sam-cli-bin`->`aws-sam-cli`,
`docker-credential-pass`->`docker-credential-helpers` (multi-tool package,
provides the `docker-credential-pass` binary), `npm`->bundled in `nodejs`,
no standalone attr (already installed unconditionally by base.nix),
`virt-install`->bundled in `pkgs.virt-manager`
(`programs.virt-manager.enable`), not a separate package.

## Config mapping notes

- **waybar-updates**: rewritten (not just ported) - was a pacman/AUR/pacdiff/
  rebuild-detector checker, none of which apply under NixOS. Now diffs the
  flake's own `flake.lock` against what `nix flake update` would produce in a
  scratch copy, reporting which inputs have newer revisions available.
  Assumes the flake is checked out at `$HOME/arch-packages` (override via
  `WAYBAR_UPDATES_FLAKE_DIR`) **and that `flake.lock` is actually committed**
  - without a committed lock file there's nothing to diff against.
- **nvim submodule + Nix**: `conf/base/etc/xdg/nvim` is a git submodule
  (`.gitmodules`), and Nix's flake git-tree filtering does not include
  submodule content by default - it'll error with
  `Path '...xdg/nvim' ... is not tracked by Git` otherwise. Every flake
  invocation needs `?submodules=1` on the flake ref (`nix flake check
  '.?submodules=1'`, `--flake '.?submodules=1#desktop'`, etc.) - see
  README.md and `bootstrap.sh` for where this is already wired in.
- **zsh**: system-wide via `programs.zsh` (`loginShellInit`/
  `interactiveShellInit`) rather than home-manager, because the vendored
  `zshrc` sources `/etc/zsh/zsh-aliases` and `/etc/zsh/p10k.zsh` by absolute
  path - those two files are kept at the same literal `/etc/zsh/*` paths via
  `environment.etc` so the vendored zshrc doesn't need editing.
  The original `zshrc` bootstrapped zsh4humans, a plugin manager that curls
  its own installer from GitHub on a new machine's first shell start; that's
  been replaced with plain nixpkgs packages (`zsh-powerlevel10k`,
  `programs.zsh.autosuggestions`/`syntaxHighlighting`) wired in directly by
  `modules/profiles/base.nix` - fetched and pinned at build time like
  everything else in this flake, not at shell-startup time. `envExtra`/
  `zshenv` was 100% that bootstrap and no longer exists.
- **Keyboard layout**: `conf/base/etc/xkb/symbols/us-hyper` is registered via
  `services.xserver.xkb.extraLayouts`, but the actual X11 keyboard config file
  (`conf/desktop/etc/X11/xorg.conf.d/00-keyboard.conf`) references a layout
  named `jc`, not `us-hyper`. That mismatch already existed in the source repo
  (this file was vendored byte-for-byte) - not something introduced by this
  migration, but worth checking on real hardware since `jc` may not resolve
  to anything without further setup this repo doesn't capture.
- **Console font**: Arch's `terminus-font` names sizes like
  `ter-132n`/`ter-716n` (Arch's own `setfont` naming); NixOS's
  `pkgs.terminus_font` ships them under the upstream `ter-v<size>n` scheme.
  The exact size numbers likely don't correspond 1:1 - `hosts/desktop` and
  `hosts/laptop` use `ter-716n`/`ter-132n` unchanged as a starting point;
  check what's actually available and adjust after boot.
- **Secure Boot / LUKS**: see the comments in `modules/secure-boot.nix` and
  `modules/luks-common.nix` for the one-time manual steps that replace
  `sbctl create-keys`/`sbctl enroll-keys` and
  `systemd-cryptenroll --fido2-device=auto` from the old `install.sh`.
- **Passwords**: nothing in this repo sets a password hash for any user (the
  old installer prompted for one interactively and baked it into the target
  filesystem at install time). Run `passwd` for root and the primary user
  after first boot.

## What to run before trusting this

On a real Linux machine with Nix installed:
```bash
nix flake check
nixos-rebuild build --flake .#desktop
nixos-rebuild build --flake .#laptop
```
Fix whatever attribute names still come back wrong and update this file as
gaps get resolved.
