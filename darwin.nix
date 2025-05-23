{ pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      gawk
    ];
  };
}
