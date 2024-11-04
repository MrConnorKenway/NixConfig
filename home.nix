{ pkgs, pkgs-unstable, ... }:

{
  home = {
    packages = with pkgs; [
      procs
      git
      pahole
      fzf
      cargo
      clang-tools
      nixd
      tree-sitter
      lua-language-server
      just
      python311Packages.python-lsp-server
    ];

    username = "dingluochangqi.ck";
    homeDirectory = "/home/dingluochangqi.ck";

    stateVersion = "24.05";

    sessionVariables = {
      TERM = "xterm-256color";
    };

    file = {
      ".clangd" = { text = ''
        CompileFlags:
          Add: [-Wno-unknown-warning-option, -Wno-address-of-packed-member]
          Remove: [-m*, -f*]
      '';
      };
    };
  };

  programs = {

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
      terminal = "screen-256color";
    };

    neovim = {
      package = pkgs-unstable.neovim-unwrapped;
      enable = true;
      vimAlias = true;

      plugins = with pkgs.vimPlugins; [
        lazy-nvim

        nvim-treesitter-parsers.c
        nvim-treesitter-parsers.cpp
        nvim-treesitter-parsers.asm
        nvim-treesitter-parsers.nix
        nvim-treesitter-parsers.cpp
        nvim-treesitter-parsers.lua
        nvim-treesitter-parsers.vim
        nvim-treesitter-parsers.make
        nvim-treesitter-parsers.query
        nvim-treesitter-parsers.vimdoc
        nvim-treesitter-parsers.python
        nvim-treesitter-parsers.markdown
      ];

      extraLuaConfig = ''
        vim.opt.list = true
        vim.opt.listchars = { tab = '⇥ ', lead = '·', trail = '•', nbsp = '␣', multispace = '·' }
        vim.opt.cursorline = true
        vim.opt.number = true
        vim.opt.ignorecase = true
        vim.opt.termguicolors = true
        vim.opt.wildmode = 'full:longest'
        vim.opt.smartcase = true

        vim.g.mapleader = ' '

        vim.api.nvim_create_autocmd('BufRead', {
          callback = function(opts)
            vim.api.nvim_create_autocmd('BufWinEnter', {
              once = true,
              buffer = opts.buf,
              callback = function()
                local ft = vim.bo[opts.buf].filetype
                local last_known_line = vim.api.nvim_buf_get_mark(opts.buf, '"')[1]
                if
                  not (ft:match('commit') and ft:match('rebase'))
                  and last_known_line > 1
                  and last_known_line <= vim.api.nvim_buf_line_count(opts.buf)
                then
                  vim.api.nvim_feedkeys([[g`"]], 'nx', false)
                end
              end,
            })
          end,
        })

        require('lazy').setup({
          {
            'lewis6991/gitsigns.nvim',
            config = function()
              local gitsigns = require('gitsigns')
              gitsigns.setup {
                signs = {
                  add = { text = '' },
                  change = { text = '' },
                  conflict = { text = '' },
                  delete = { text = '' }
                }
              }
              vim.keymap.set('n', ']c', function() gitsigns.nav_hunk('next') end, { desc = 'Go to next git change' })
              vim.keymap.set('n', '[c', function() gitsigns.nav_hunk('prev') end, { desc = 'Go to previous git change' })
            end
          },
          {
            "folke/flash.nvim",
            event = "VeryLazy",
            ---@type Flash.Config
            opts = {},
            -- stylua: ignore
            keys = {
              { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
              { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
              { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
              { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
              { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
            },
          },
          {
            'nvim-treesitter/nvim-treesitter',
            opts = {
              highlight = { enable = true },
              indent = { enable = true }
            }
          },
          {
            'catppuccin/nvim',
            priority = 1000,
            init = function()
              vim.cmd.colorscheme 'catppuccin'
            end
          },
          {
            'akinsho/toggleterm.nvim',
            keys = {
              { '<leader>t', function() vim.cmd([[ToggleTerm direction='float']]) end, desc = 'Toggle floating terminal' }
            },
            config = function()
              require('toggleterm').setup {
                shading_factor = 2,
                float_opts = { border = 'rounded' }
              }
            end
          },
          {
            'nmac427/guess-indent.nvim',
            config = function()
              require('guess-indent').setup()
            end
          },
          { 'nvim-tree/nvim-web-devicons', lazy = true },
          {
            'nvim-lualine/lualine.nvim',
            config = function()
              require('lualine').setup()
            end
          },
          {
            'neovim/nvim-lspconfig',
            config = function()
              vim.api.nvim_create_autocmd('LspAttach', {
                callback = function(event)
                  vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, {
                    border = 'rounded'
                  })

                  vim.keymap.set('n', 'gh', vim.lsp.buf.hover, { desc = 'Go to type definitions' })
                end
              })

              local lspconfig = require('lspconfig')
              lspconfig.clangd.setup{}
              lspconfig.nixd.setup{}
              lspconfig.lua_ls.setup{}
              lspconfig.pylsp.setup{}
            end
          },
          {
            'nvim-telescope/telescope.nvim',
            keys = {
              { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'Telescope find files' },
              { '<leader>fg', '<cmd>Telescope live_grep<cr>', desc = 'Telescope live grep' },
              { '<leader>fb', '<cmd>Telescope buffers<cr>', desc = 'Telescope buffers' },
              { '<leader>fh', '<cmd>Telescope help_tags<cr>', desc = 'Telescope help tags' },
              { '<leader>fs', '<cmd>Telescope lsp_dynamic_workspace_symbols<cr>', desc = 'Telescope find workspace symbols' },
              { '<leader>r',  '<cmd>Telescope lsp_references<cr>', desc = 'Go to references' },
              { 'gd',         '<cmd>Telescope lsp_definitions<cr>', desc = 'Go to definitions' },
              { 'gy',         '<cmd>Telescope lsp_type_definitions<cr>', desc = 'Go to type definitions' }
            },
            dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope-ui-select.nvim' },
            config = function()
              require('telescope').setup {
                defaults = {
                  sorting_strategy = 'ascending',
                  layout_config = {
                    horizontal = { prompt_position = 'top' },
                    preview_cutoff = 120
                  }
                }
              }
            end
          }
        }, {
          performance = {
            rtp = {
              disabled_plugins = {
                'gzip', 'netrwPlugin', 'tarPlugin', 'tohtml', 'zipPlugin'
              }
            }
          }
        })

        -- require('leap').create_default_mappings()
        -- require('leap.user').set_repeat_keys(';', ',', {
        --   relative_directions = true,
        --   modes = {'n'}
        -- })

        -- require('astrotheme').setup({
        --   palette = 'astrodark',
        --   style = {
        --       transparent = false,         -- Bool value, toggles transparency.
        --       inactive = true,             -- Bool value, toggles inactive window color.
        --       float = true,                -- Bool value, toggles floating windows background colors.
        --       neotree = true,              -- Bool value, toggles neo-trees background color.
        --       border = true,               -- Bool value, toggles borders.
        --       title_invert = true,         -- Bool value, swaps text and background colors.
        --       italic_comments = true,      -- Bool value, toggles italic comments.
        --       simple_syntax_colors = true, -- Bool value, simplifies the amounts of colors used for syntax highlighting.
        --   }
        -- })
        -- vim.cmd([[colorscheme astrotheme]])

        -- require('ibl').setup {
        --   indent = {
        --     char = "│",
        --     tab_char = "⇥"
        --   },
        --   scope = { show_start = false, show_end = false }
        -- }

        -- local bufferline = require('bufferline')
        -- bufferline.setup {
        --   options = {
        --     mode = 'buffers', -- set to 'tabs' to only show tabpages instead
        --     style_preset = bufferline.style_preset.default, -- or bufferline.style_preset.minimal,
        --     diagnostics = 'nvim_lsp',
        --     diagnostics_update_in_insert = false,
        --     offsets = {
        --       {
        --         filetype = 'neo-tree',
        --         text = 'File Explorer',
        --         text_align = 'left',
        --         separator = true,
        --       },
        --     },
        --     color_icons = true, -- whether or not to add the filetype icon highlights
        --   },
        -- }

        -- vim.lsp.inlay_hint.enable()
      '';
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

