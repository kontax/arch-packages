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

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, disko, lanzaboote, ... }:
    let
      system = "x86_64-linux";

      overlay = import ./pkgs;

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
          ] ++ extraModules;
        };
    in
    {
      overlays.default = overlay;

      nixosConfigurations = {
        # Dual-monitor sway desktop: base + desktop + dev
        desktop = mkHost { hostName = "desktop"; };

        # HiDPI sway laptop: base + desktop + laptop + dev
        laptop = mkHost { hostName = "laptop"; };
      };
    };
}
