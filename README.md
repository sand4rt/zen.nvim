# 🧘🏼‍♂️ zen.nvim

![zen mode by https://github.com/alex35mil/dotfiles](https://user-images.githubusercontent.com/4244251/266051812-5adc68e7-e2ac-4f1e-9093-f995cbd0f561.png "Zen mode by https://github.com/alex35mil/dotfiles")

## Capabilities

- Simple plugin that centers the main buffer.
- Compatible with side buffer plugins _(like
  [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim))_.
- Automatically toggles side buffers whenever a side buffer is opened/closed
  without flickering.
- Responsive during resizing.
- Supports tabs, horizontal and vertical splits.
- Layout and positioning options.
- Removes the need for a visual guide showing the maximum line width
  _(`ColorColumn`)_.
- Reduces neck strain and improves focus.

## Usage

<details>
<summary>Using <a href="https://github.com/folke/lazy.nvim">Lazy.nvim</a></summary>

```lua
return {
  "sand4rt/zen.nvim",
  lazy = false,
  opts = {
    main = {
      width = 148, -- or vim.wo.colorcolumn
    },
    -- TIP: find a buffer's filetype with :lua print(vim.bo.filetype)
    top = {
      { filetype = "gitcommit", replace = false },
      { filetype = "fugitive" },
      { filetype = "man" },
      { filetype = "help" },
    },
    right = {
      { filetype = "*", min_width = 46 },
      { filetype = "copilot-chat", min_width = 60 },
      { filetype = "neotest-summary" },
      { filetype = { "dapui_watches", "dapui_scopes", "dapui_stacks", "dapui_breakpoints" } },
    },
    bottom = {
      { filetype = "dap-repl" },
      { filetype = "qf" },
      { filetype = "trouble" },
      { filetype = "noice" }, -- noice opens large notifications in a buffer
    },
    left = {
      { filetype = "*", min_width = 46 },
      { filetype = "fugitiveblame" },
      { filetype = "fyler_finder" },
      { filetype = "neotree" },
      { filetype = "dbui" },
      { filetype = { "undotree", "diff" } },
    },
  },
}
```

</details>

<details>
<summary>Using <a href="https://github.com/NotAShelf/nvf">Nix NVF</a></summary>

```nix
programs.nvf.settings.vim.lazy.plugins = {
  "zen.nvim" = {
    package = pkgs.vimPlugins.zen-nvim;
    event = [ "BufEnter" ];
    setupModule = "zen";
    setupOpts = {
      main.width = 148;
      # TIP: find a buffer's filetype with :lua print(vim.bo.filetype)
      top = [
        { filetype = "gitcommit"; replace = false; }
        { filetype = "fugitive"; }
        { filetype = "man"; }
        { filetype = "help"; }
      ];
      right = [
        { filetype = "*"; min_width = 46; }
        { filetype = "copilot-chat"; min_width = 60; }
        { filetype = "neotest-summary"; }
        { filetype = [ "dapui_watches" "dapui_scopes" "dapui_stacks" "dapui_breakpoints" ]; }
      ];
      bottom = [
        { filetype = "dap-repl"; }
        { filetype = "qf"; }
        { filetype = "trouble"; }
        { filetype = "noice"; } # noice opens large notifications in a buffer
      ];
      left = [
        { filetype = "*"; min_width = 46; }
        { filetype = "fugitiveblame"; }
        { filetype = "fyler_finder"; }
        { filetype = "neotree"; }
        { filetype = "dbui"; }
        { filetype = [ "undotree" "diff" ]; }
      ];
    };
  };
};
```

</details>

## Credits to other plugins for inspiration

- [folke/edgy.nvim](https://github.com/folke/edgy.nvim)
- [shortcuts/no-neck-pain.nvim](https://github.com/shortcuts/no-neck-pain.nvim)
- [folke/zen-mode.nvim](https://github.com/folke/zen-mode.nvim)
- [pocco81/true-zen.nvim](https://github.com/pocco81/true-zen.nvim)
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim/blob/main/docs/zen.md)
