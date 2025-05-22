{ pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      pahole
    ];
  };
}
