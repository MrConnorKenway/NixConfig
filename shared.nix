{
  config,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  home = {
    packages =
      with pkgs;
      [
        procs
        git
        clang-tools
        nixd
        lua-language-server
        basedpyright
        rustup
        stylua
        home-manager
        termtheme
        (writeShellScriptBin "vi" ''
          theme=$(${pkgs.termtheme}/bin/termtheme --force)
          case $theme in
            light|dark)
              nvim --cmd "set bg=$theme" "$@"
              ;;
            *)
              nvim "$@"
              ;;
          esac
        '')
        nixfmt-rfc-style
        inetutils
        ollama
        aichat
        eza
      ]
      ++ [
        pkgs-unstable.zig
        pkgs-unstable.zls
      ];

    username = builtins.getEnv "USER";
    homeDirectory = builtins.getEnv "HOME";

    stateVersion = "25.05";

    file = {
      ".clangd" = {
        text = ''
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
    less = {
      enable = true;
      keys = ''
        #line-edit
        ^A home
        ^E end
        ^F right
        ^B left
        ^P up
        ^N down
        ^D delete
        ^W word-backspace
        \ed word-delete
        \ef word-right
      '';
    };

    fzf = {
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

    fd = {
      enable = true;
      extraOptions = [
        "--no-ignore"
        "--hidden"
      ];
    };

    ripgrep = {
      enable = true;
      arguments = [
        "--no-ignore"
        "--no-heading"
      ];
    };

    tmux = {
      enable = true;
      keyMode = "vi";
      prefix = "C-j";
      escapeTime = 10;

      plugins = with pkgs.tmuxPlugins; [
        nord
        prefix-highlight
      ];
    };

    neovim = {
      enable = true;
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      completionInit = ''
        autoload -U compinit && compinit
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      '';

      initContent = ''
        autoload -U select-word-style
        select-word-style bash
        zshaddhistory() { whence ''\${''\${(z)1}[1]} >| /dev/null || return 1 }
      '';

      shellAliases = {
        l = "eza -l --icons";
        ls = "eza";
        ll = "eza -l --icons";
        la = "eza -la --icons";
        ld = "eza --only-dirs";
        lt = "eza --tree --icons";
        gd = "git diff";
        gl = "git log";
        gu = "git push";
        gp = "git pull";
        gf = "git fetch";
        gst = "git status";
        glg = "git log --stat";
        grba = "git rebase --abort";
        gsta = "git stash push";
        gstp = "git stash pop";
        gstd = "git stash drop";
        gloga = "git log --oneline --decorate --graph --all";
      };

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
          name = "zsh-autopair";
          src = "${pkgs.zsh-autopair}/share/zsh/zsh-autopair";
          file = "autopair.zsh";
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
        {
          name = "termsupport";
          src = ./.;
          file = "termsupport.zsh";
        }
      ];
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
    };
  };
}
