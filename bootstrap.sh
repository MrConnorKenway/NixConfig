#!/bin/bash

os=$(uname)

if [ "$os" = "Darwin" ]; then
	curl -fsSL https://install.determinate.systems/nix | sh -s -- install
else
	sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon
fi

mkdir -p $HOME/.config/nix

echo substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/ > $HOME/.config/nix/nix.conf
echo experimental-features = nix-command flakes >> $HOME/.config/nix/nix.conf

if [ "$os" = "Darwin" ]; then
	export PATH=/nix/var/nix/profiles/default/bin:$PATH
	nix run home-manager/master -- switch --flake .#darwin --impure
else
	export PATH=$HOME/.nix-profile/bin:$PATH
	nix run home-manager/master -- switch --flake .#linux --impure
fi
