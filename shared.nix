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
        nixfmt
        eza
        delta
        sshpass
        tree-sitter
      ]
      ++ (with pkgs-unstable; [
        zig
        zls
        lazygit
      ]);

    username = builtins.getEnv "USER";
    homeDirectory = builtins.getEnv "HOME";

    sessionVariables = {
      LS_COLORS = "";
    };

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.cargo/bin"
    ];

    stateVersion = "26.05";

    file = {
      ".hushlogin" = {
        text = "";
      };
      ".clangd" = {
        text = ''
          CompileFlags:
            Add: [-Wno-unknown-warning-option, -Wno-address-of-packed-member]
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
      package = pkgs-unstable.fzf;
      enable = true;
      defaultOptions = [
        "--bind ctrl-d:half-page-down,ctrl-u:half-page-up --no-mouse"
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
      sideloadInitLua = true;
    };

    fish = {
      enable = true;

      shellInit = ''
        if test -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
          source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
        else if test -r "$HOME/.nix-profile/etc/profile.d/nix.fish"
          source "$HOME/.nix-profile/etc/profile.d/nix.fish"
        end
      '';

      interactiveShellInit = ''
        set -g fish_greeting
        set -g fish_color_command blue
        ${builtins.readFile p10k-config/p10k.fish}

        function __long_command_preexec --on-event fish_preexec
          set -l last_status $status
          if set -q __long_command_reported
            printf '\e]7501;state=clear:id=fish-%s\a' $fish_pid
            set -e __long_command_reported
          end
          return $last_status
        end

        function __long_command_postexec --on-event fish_postexec
          set -l last_status $status
          if not set -q CMD_DURATION; or test "$CMD_DURATION" -le 3000; or test $last_status -eq 130
            return $last_status
          end

          if set -q REX_SESSION
            set -l tokens
            printf '%s\0' "$argv[1]" | read --null --tokenize --list tokens
            while contains -- "$tokens[1]" command builtin exec
              set -e tokens[1]
              if test "$tokens[1]" = --
                set -e tokens[1]
              end
            end
            set -l app (path basename -- "$tokens[1]")
            string match --quiet --regex '^[A-Za-z0-9_.+-]{1,32}$' -- "$app"; or set app fish
            set -l state done
            test $last_status -eq 0; or set state error
            printf '\e]7501;state=%s:app=%s:id=fish-%s\a' $state $app $fish_pid
            set -g __long_command_reported 1
          else
            set -l text (string replace --all --regex '[[:cntrl:];]' ' ' -- "$argv[1]" | string collect)
            printf '\e]777;notify;;"%s" finished\a' "$text"
          end
          return $last_status
        end
      '';

      binds.tab.command = "fzf_complete --select-1";

      shellAliases = {
        l = "eza -l --icons=auto";
        ls = "eza";
        ll = "eza -l --icons=auto";
        la = "eza -la --icons=auto";
        ld = "eza --only-dirs";
        lt = "eza --tree --icons=auto";
        lg = "lazygit -ucf ${lazygit/config.yml}";
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
        vi = "nvim";
      };
    };

    atuin = {
      enable = true;
      enableFishIntegration = true;

      settings = {
        # No cloud synchronization or update requests
        auto_sync = false;
        update_check = false;

        # Per-directory command history
        filter_mode = "directory";
        filter_mode_shell_up_key_binding = "directory";

        # Disable AI features
        ai.enabled = false;

        # full screen history
        inline_height = 0;
      };
    };

    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
  };
}
