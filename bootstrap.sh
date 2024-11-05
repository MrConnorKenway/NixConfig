#!/bin/bash

sh <(curl https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install)
nix-channel --add https://github.com/nix-community/home-manager/archive/release-24.05.tar.gz home-manager # change 24.05 to match latest nixpkgs version
nix-channel --update
nix-shell '<home-manager>' -A install
home-manager switch --flake . --impure
