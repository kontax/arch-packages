{
  description = "couldinho NixOS systems (base/desktop/laptop/dev)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tracks master rather than a release tag - v0.4.1 pinned to a nixpkgs
    # revision old enough that `boot.bootspec.enable` (which that release
    # still sets) has since been removed from nixpkgs entirely, breaking
    # `nix flake check` outright. master tracks nixpkgs-unstable.
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, disko, lanzaboote, ... }:
    let
      system = "x86_64-linux";

      overlay = import ./pkgs;

      # Personal values (currently just a GPG key ID/URL - see
      # modules/options.nix and home/programs/gpg-import.nix) don't belong in
      # this public repo. Lives outside the repo entirely (not just
      # gitignored) - Nix flakes only evaluate files tracked by git, so a
      # gitignored-and-untracked local.nix at the repo root was silently
      # invisible to flake evaluation no matter what it contained. Reading
      # from $HOME requires --impure (see README.md's rebuild command).
      localPath = builtins.getEnv "HOME" + "/.config/couldinho/local.nix";
      localModule = nixpkgs.lib.optional (builtins.pathExists localPath) localPath;

      mkHost = { hostName, extraModules ? [ ] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit self; };
          modules = [
            { nixpkgs.overlays = [ overlay ]; }
            disko.nixosModules.disko
            lanzaboote.nixosModules.lanzaboote
            home-manager.nixosModules.home-manager
            ./modules/options.nix
            ./modules/secure-boot.nix
            ./modules/luks-common.nix
            ./hosts/${hostName}
            { networking.hostName = hostName; }
          ] ++ localModule ++ extraModules;
        };
    in
    {
      overlays.default = overlay;

      nixosConfigurations = {
        # Dual-monitor sway desktop: base + desktop + dev
        desktop = mkHost { hostName = "desktop"; };

        # Proxmox VM used to develop/test the desktop host before deploying
        # to the real machine above - see hosts/desktop-vm's own comments.
        desktop-vm = mkHost { hostName = "desktop-vm"; };

        # HiDPI sway laptop: base + desktop + laptop + dev
        laptop = mkHost { hostName = "laptop"; };
      };
    };
}
