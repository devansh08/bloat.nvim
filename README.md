# bloat.nvim

Plugin to open and maintain multiple **b**uffers/windows that f**loat**.

## Installation

Install using your favorite package manager, like any other plugin.

For example, with lazy.nvim:
```lua
{
  "devansh08/bloat.nvim",
  branch = "main",
  ---@type BloatOpts
  opts = {
    width = 0.75, -- Width of floating window in percent
    height = 0.75, -- Height of floating window in percent
    highlight = { -- Highlight for buffer title; Defaults to `FloatTitle` group
      fg = "",
      bg = ""
    },
    border = "single", -- Border style for floating window; Valid values: "double" | "none" | "rounded" | "shadow" | "single" | "solid"
    name_prefix = "Scratch" -- Buffer title prefix; Used with index unless buffer is saved manually
  },
}
```

## Usage

The plugin exposes multiple user commands to interact with these buffers:
- `BloatCreate`: Creates a new buffer and opens it in a floating window. Takes an optional argument that can be used as the buffer name; defaults to `<name_prefix || 'Scratch'> <buffer_count>`.
- `BloatOpen`: Opens a floating window with an already created/restored buffer. Takes one argument with the name of the buffer. Supports autocomplete.
- `BloatClose`: Closes the currently open floating window.
- `BloatToggle`: Toggles the state of the floating window with the most recently accessed buffer, i.e., if floating window is opened the command closes it, else it opens the window with the last open buffer.
- `BloatRename`: Renames the current buffer in the open floating window. Will fail if the floating window is closed.

## Saving and Restoring

The buffers are stored under `~/.local/state/nvim/bloat.nvim`, following `<sha256_of_cwd>_<buffer_name_hyphen_separated>` naming scheme. All spaces in the buffer name are replaced by `-`. The buffer name here will be either `<name_prefix || 'Scratch'> <buffer_count>` or whatever was set by the `BloatRename` command.

> [!WARNING]
> Saving the buffer with `:w <name>` does not set the name of the buffer that `bloat.nvim` uses for tracking. It would instead create a new file in the CWD named `<name>`.
> 
> If this is done accidentally, deleting the file in the CWD should be safe, as the file tracked under the state directory will still be used.

Restoring of the buffers is done automatically on startup of the plugin. It looks in the mentioned state directory for any files starting with the SHA256 hash of the CWD and loads those files as buffers. This does not automatically open a floating window. `BloatOpen` can be used, once buffers are loaded, to open them in the floating window.

> [!NOTE]
> The entire SHA256 value is not used when naming the file as that would create a very long file name, that may then interfere with certain underlying FS rules for file name lengths; specially considering buffer names are appended to this value. Instead the first 16 characters are used, which should be unique enough for this use case. 
> 
> If `git` can work with 8 characters of SHA1/SHA256, `bloat.nvim` is fine with 16 :)
> 
> Additionally, SHA256 is used as that is present as a built-in hash function in neovim's Lua API :)
