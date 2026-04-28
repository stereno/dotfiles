{ config, pkgs, lib, ... }:
let
  plugins = with pkgs.vimPlugins; [
    LazyVim
    snacks-nvim
    bufferline-nvim
    flash-nvim
    which-key-nvim
    gitsigns-nvim
    trouble-nvim
    todo-comments-nvim
    grug-far-nvim
    lazydev-nvim
    lualine-nvim
    noice-nvim
    nui-nvim
    persistence-nvim
    plenary-nvim
    nvim-lint
    nvim-lspconfig
    conform-nvim
    nvim-treesitter
    nvim-treesitter-textobjects
    nvim-ts-autotag
    telescope-nvim
    telescope-fzf-native-nvim
    dressing-nvim
    yazi-nvim
    tokyonight-nvim
    blink-cmp
    friendly-snippets
    {
      name = "catppuccin";
      path = pkgs.vimPlugins.catppuccin-nvim;
    }
    {
      name = "mini.ai";
      path = pkgs.vimPlugins.mini-nvim;
    }
    {
      name = "mini.icons";
      path = pkgs.vimPlugins.mini-nvim;
    }
    {
      name = "mini.pairs";
      path = pkgs.vimPlugins.mini-nvim;
    }
  ];

  mkEntryFromDrv =
    drv:
    if lib.isDerivation drv then
      {
        name = lib.getName drv;
        path = drv;
      }
    else
      drv;

  lazyPath = pkgs.linkFarm "lazyvim-plugins" (map mkEntryFromDrv plugins);

  treesitter = pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
    p.bash
    p.c
    p.diff
    p.go
    p.gomod
    p.gosum
    p.gowork
    p.html
    p.javascript
    p.jsdoc
    p.json
    p.lua
    p.luadoc
    p.luap
    p.markdown
    p.markdown_inline
    p.nix
    p.printf
    p.python
    p.query
    p.regex
    p.rust
    p.toml
    p.tsx
    p.typescript
    p.vim
    p.vimdoc
    p.xml
    p.yaml
  ]);

  parsers = pkgs.symlinkJoin {
    name = "treesitter-parsers";
    paths = treesitter.dependencies;
  };
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withRuby = false;
    withPython3 = false;

    plugins = with pkgs.vimPlugins; [
      lazy-nvim
    ];

    extraPackages = with pkgs; [
      gcc
      tree-sitter
      ripgrep
      fd
      nil
      lua-language-server
      typescript-language-server
      pyright
      gopls
      rust-analyzer
      nixfmt
      stylua
      prettierd
      black
      go
      rustfmt
    ];

    initLua = ''
      vim.g.lazyvim_nix_lazy_path = "${lazyPath}"
      require("config.lazy")
    '';
  };

  xdg.configFile."nvim/lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home/nvim/lua";
  xdg.configFile."nvim/parser".source = "${parsers}/parser";
}
