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
        eza
        delta
        lazygit
        (writeShellScriptBin "lg" ''
          theme=$(${pkgs.termtheme}/bin/termtheme --force)
          case $theme in
            light|dark)
              ${pkgs.lazygit}/bin/lazygit -ucf "$HOME/.config/lazygit/$theme.yml,$HOME/.config/lazygit/config.yml" "$@"
              ;;
            *)
              ${pkgs.lazygit}/bin/lazygit -ucf "$HOME/.config/lazygit/light.yml,$HOME/.config/lazygit/config.yml" "$@"
              ;;
          esac
        '')
        sshpass
      ]
      ++ (with pkgs-unstable; [
        zig
        zls
      ]);

    username = builtins.getEnv "USER";
    homeDirectory = builtins.getEnv "HOME";

    sessionVariables = {
      LS_COLORS = "";
    };

    stateVersion = "25.11";

    file = {
      ".hushlogin" = {
        text = "";
      };
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
      ".config/lazygit".source = ./lazygit;
    };
  };

  programs = {
    less = {
      enable = true;
      config = ''
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
      defaultOptions = [
        "--bind ctrl-d:half-page-down,ctrl-u:half-page-up"
      ];
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
      terminal = "screen-256color";

      plugins = with pkgs.tmuxPlugins; [
        nord
        prefix-highlight
      ];
    };

    neovim = {
      package = pkgs-unstable.neovim-unwrapped;
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
        zstyle ':fzf-tab:*' fzf-bindings 'ctrl-a:toggle-all+accept' 'alt-n:toggle-down' 'alt-p:up+toggle' 'ctrl-d:half-page-down' 'ctrl-u:half-page-up'
      '';

      initContent = ''
        autoload -U select-word-style
        select-word-style bash
      '';

      shellAliases = {
        l = "eza -l --icons=auto";
        ls = "eza";
        ll = "eza -l --icons=auto";
        la = "eza -la --icons=auto";
        ld = "eza --only-dirs";
        lt = "eza --tree --icons=auto";
        gl = "lg log";
        gs = "lg status";
        ga = "git add";
        gd = "git diff";
        gu = "git push";
        gp = "git pull";
        gf = "git fetch";
        gds = "git diff --staged";
        gcb = "git checkout -b";
        gco = "git checkout";
        gst = "git status";
        glg = "git log --stat";
        grh = "git reset --hard";
        grba = "git rebase --abort";
        grbc = "git rebase --continue";
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
            sha256 = "EV9QPBndwAWzdOcghDXrIIgP0oagVMOTyXzoyt8tXRo=";
          };
          file = "per-directory-history.zsh";
        }
        {
          name = "termsupport";
          src = ./.;
          file = "termsupport.zsh";
        }
        {
          name = "fzf-tab";
          src = pkgs.fetchFromGitHub {
            owner = "Aloxaf";
            repo = "fzf-tab";
            rev = "v1.2.0";
            sha256 = "q26XVS/LcyZPRqDNwKKA9exgBByE0muyuNb0Bbar2lY=";
          };
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
