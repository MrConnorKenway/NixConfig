{ pkgs, config, ... }:

{
  home = {
    packages = with pkgs; [
      gawk
    ];

    file = {
      ".config/ghostty/config" = {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/NixConfig/ghostty.conf";
      };
    };
  };
}
