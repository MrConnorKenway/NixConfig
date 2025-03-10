#!/bin/bash

nix-channel --add https://github.com/nix-community/home-manager/archive/release-24.11.tar.gz home-manager # change 24.05 to match latest nixpkgs version
nix-channel --update
nix-shell '<home-manager>' -A install

if [ "$(uname)" = "Darwin" ]; then
	home-manager switch --flake .#darwin --impure
else
	home-manager switch --flake .#linux --impure
fi
