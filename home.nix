{ config, pkgs, pkgs-unstable, ... }:

{
  home = {
    packages = with pkgs; [
      tree
      procs
      git
      pahole
      clang-tools
      nixd
      tree-sitter
      lua-language-server
      just
      basedpyright
      zoxide
      rustup
      stylua
    ];

    username = builtins.getEnv "USER";
    homeDirectory = builtins.getEnv "HOME";

    stateVersion = "24.11";

    file = {
      ".clangd" = { text = ''
        CompileFlags:
          Add: [-Wno-unknown-warning-option, -Wno-address-of-packed-member]
          Remove: [-m*, -f*]
      '';
      };
      ".config/nvim" = {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/NixConfig/nvim";
      };
    };
  };

  programs = {

    fzf = {
      package = pkgs-unstable.fzf;
      enable = true;
    };

    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    zoxide = {
      enable = true;
    };

    fd = {
      enable = true;
      extraOptions = [ "--no-ignore" "--hidden" ];
    };

    ripgrep = {
      enable = true;
      arguments = [ "--no-ignore" "--no-heading" ];
    };

    tmux = {
      enable = true;
      keyMode = "vi";
      prefix = "C-j";
      terminal = "tmux-256color";
      escapeTime = 10;

      plugins = with pkgs.tmuxPlugins; [
        nord
        prefix-highlight
      ];
    };

    neovim = {
      package = pkgs-unstable.neovim-unwrapped;
      enable = true;
      vimAlias = true;
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      history = {
        extended = true;
        size = 1000000;
        share = true;
      };

      plugins = [
        {
          name = "zsh-powerlevel10k";
          src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/";
          file = "powerlevel10k.zsh-theme";
        }
        {
          name = "powerlevel10k-config";
          src = ./p10k-config;
          file = "p10k.zsh";
        }
        {
          name = "per-directory-history";
          src = pkgs.fetchFromGitHub {
            owner = "jimhester";
            repo = "per-directory-history";
            rev = "master";
            sha256 = "eURWxwUL82MzsDgfjp6N3hT2ddeww8Vddcq0WxgCbnc=";
          };
          file = "per-directory-history.zsh";
        }
      ];

      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "fzf" ];
      };

      shellAliases = {
        cat = "bat";
      };
    };

    home-manager.enable = true;

  };
}

