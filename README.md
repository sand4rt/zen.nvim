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
      -- `width` accepts a number, a function returning a number,
      -- or a table mapping monitor names to widths.
      -- Use "*" as the wildcard/default key in the table.
      -- Provide `monitor_name` (a function returning a string) to enable
      -- per-monitor table lookups; without it the $MONITOR env var is tried.
      width = 148, -- or vim.wo.colorcolumn
    },
    -- TIP: find a buffer's filetype with :lua print(vim.bo.filetype)
    top = {
      { filetype = "man" },
      { filetype = "help" },
      { filetype = "fugitive" },
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
      { filetype = "fyler" },
      { filetype = "neotree" },
      { filetype = "dbui" },
      { filetype = { "undotree", "diff" } },
    },
  },
}
```

</details>

<details>
<summary>Multi-monitor / dynamic width</summary>

`width` in `main` can be a **number**, a **function**, or a **table** mapping monitor names to widths.
Use `"*"` as the wildcard that is returned when no specific monitor key matches.

When `width` is a table the plugin resolves the current monitor name by calling the optional
`monitor_name` function you provide. If `monitor_name` is omitted the `$MONITOR` environment
variable is tried before falling back to `"*"`.

```lua
-- Simple table – relies on $MONITOR env var for resolution
require("zen").setup({
  main = {
    width = {
      ["*"]    = 148,  -- default / fallback
      ["DP-1"] = 110,  -- 1080p external
      ["eDP-1"] = 85,  -- laptop built-in display
    },
  },
})

-- Table with an explicit resolver (Hyprland example)
require("zen").setup({
  main = {
    monitor_name = function()
      local ok, result = pcall(function()
        local handle = assert(io.popen("hyprctl monitors -j"))
        local output = handle:read("*a")
        handle:close()
        return output
      end)
      if not ok then return nil end
      local monitors = vim.json.decode(result)
      for _, mon in ipairs(monitors) do
        if mon.focused then return mon.name end
      end
    end,
    width = {
      ["*"]    = 148,
      ["DP-1"] = 110,
      ["eDP-1"] = 85,
    },
  },
})

-- Function – full dynamic control
require("zen").setup({
  main = {
    width = function()
      -- return any number based on runtime conditions
      return vim.o.columns > 200 and 148 or 110
    end,
  },
})
```

</details>

<details>
<summary>Using <a href="https://github.com/NotAShelf/nvf">Nix NVF</a></summary>

```nix
programs.nvf.settings.vim.lazy.plugins = {
  "zen.nvim" = {
    package = pkgs.vimUtils.buildVimPlugin {
      pname = "zen.nvim";
      version = "1.0.0";
      src = pkgs.fetchFromGitHub {
        owner = "sand4rt";
        repo = "zen.nvim";
        rev = "v1.0.0";
        sha256 = "sha256-SVDf8K/eo8N9Hrx2rzMnW2uBDGWaJ8TZZNB/qdfJPfE=";
      };
    };
    event = [ "BufEnter" ];
    setupModule = "zen";
    setupOpts = {
      main = {
        width = 148;
      };
      # TIP: find a buffer's filetype with :lua print(vim.bo.filetype)
      top = [
        { filetype = "fugitive"; }
        { filetype = "git"; }
        { filetype = "man"; }
        { filetype = "help"; }
        { filetype = "gitcommit"; }
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
        { filetype = "fyler"; }
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
