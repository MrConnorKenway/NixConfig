{
  description = "My Home Manager configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nixpkgs-unstable, ... }:
    let
      mkHomeConfiguration = system: args: home-manager.lib.homeManagerConfiguration ({
        pkgs = import nixpkgs { inherit system; };
        extraSpecialArgs = {
          pkgs-unstable = import nixpkgs-unstable { inherit system; };
        };
      } // args);
    in {
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

