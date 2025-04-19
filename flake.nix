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
      overlay = final: prev: {
        termtheme =
          assert !(prev ? termtheme); # make sure nixpkgs does not contain termtheme
          prev.rustPlatform.buildRustPackage {
            name = "termtheme";
            src = prev.fetchFromGitHub {
              owner = "bash";
              repo = "terminal-colorsaurus";
              rev = "f99ff455e2d3272c9accf3cee6b759c1702d7892";
              hash = "sha256-LZdXKJYEq2L4zhVWVZCJbM9zf3cmNpdBWK4hQv1W4+0=";
            };
            useFetchCargoVendor = true;
            cargoHash = "sha256-dzIjYAizPDe5//YHV7DyxVNHrF7xfLMJdK6x+YI2hQA=";
            buildAndTestSubdir = "crates/termtheme";
          };
      };
      mkHomeConfiguration = system: args: home-manager.lib.homeManagerConfiguration ({
        pkgs = import nixpkgs { inherit system; overlays = [overlay]; };
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

