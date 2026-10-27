{
  description = "My Home Manager configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    per-directory-history = {
      url = "github:jimhester/per-directory-history/master";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nixpkgs-unstable,
      per-directory-history,
      ...
    }:
    let
      mkHomeConfiguration =
        system: args:
        home-manager.lib.homeManagerConfiguration (
          {
            pkgs = import nixpkgs { inherit system; };
            extraSpecialArgs = {
              inherit per-directory-history;
              pkgs-unstable = import nixpkgs-unstable { inherit system; };
            };
          }
          // args
        );
    in
    {
      homeConfigurations = {
        linux = mkHomeConfiguration "x86_64-linux" {
          modules = [
            ./linux.nix
            ./shared.nix
          ];
        };
        darwin = mkHomeConfiguration "aarch64-darwin" {
          modules = [
            ./darwin.nix
            ./shared.nix
          ];
        };
      };
    };
}
