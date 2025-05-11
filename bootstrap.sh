#!/bin/bash

VERSION=24.11

nix-channel --add https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixos-$VERSION nixpkgs
nix-channel --add https://github.com/nix-community/home-manager/archive/release-$VERSION.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install

if [ "$(uname)" = "Darwin" ]; then
	home-manager switch --flake .#darwin --impure
else
	home-manager switch --flake .#linux --impure
fi
