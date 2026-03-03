{ pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      pahole
    ];
  };

  programs.zsh = {
    envExtra = ''
      if [[ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]]; then
        . $HOME/.nix-profile/etc/profile.d/nix.sh
      fi
    '';
  };
}
