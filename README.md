# tmux-repl.nvim

This plugin provides a simple method for passing code snippets in your `neovim`
buffer to a [`tmux`][tmux] pane. As of writing, I prefer using a [`tmux`][tmux] pane to
handle the output of command as the handling of non-text outputs of `tmux` is
closer to the vanilla terminal experience, but this may change in the future!

A word of caution before using this plugin. This plugin attempts to send whatever is
in the vim buffer in the `tmux` windows as is, without fb

## Installation

Installing via lazy is fairly straight forwards. This plugin does not include
any key binds right out of the box, so below are a couple of basic
recommendations:

```lua
return {
	"yimuchen/tmux-repl.nvim",
	config = function()
		local repl = require("tmux-repl")
		repl.setup({
			-- What is the index that the plugin should push the REPL pane
			-- to if the user requests that the pane be send to the background.
			-- This default to nine.
			repl_pane_bkg_idx = 9,
			-- What to name the window when the window is sent to the background.
			repl_pane_bkg_name = "(repl-bkg)",
			-- How to generate the command string to start up the REPL pane
			-- If left at nil, it will spawn the default tmux shell, so you might need
			-- to execute some additional commands in the shell before you can
			-- actually reliably use the REPL tool. This takes a function so that
			-- the user can have a arbitrary logic to detect the environment.
			repl_start_cmd = nil,
			-- A very simple example is to always spawn a python shell
			-- repl_start_cmd = function()
			--   return "python"
			--end,
		})
		-- Example of using which key to set the key maps
		local wk = require("which-key")
		wk.add({
			{ "<leader>r", group = "[R]EPL" },
			{ "<leader>rt", repl.toggle_repl_pane, desc = "[R]EPL [T]ermial" },
			{ "<leader>rk", repl.repl_pane_close, desc = "[R]EPL [K]ill session" },
			{ "<leader>rp", repl.repl_pass_visual, desc = "[R]EPL [P]ass selection", mode = "v" },
		})
	end,
}
```

In general, the function that are most relevant to the users includes the following:

- `tmux.repl_pane_foreground`: Either bring the background `tmux` pane from the
  background to a split pane next to the editor; or spawn a new `tmux` pane for
  REPL evaluation if the background pane does not exist.
- `tmux.repl_pane_background`: Send the split pane to the background window if
  it exists.
- `tmux.repl_pane_toggle`: Background/foreground switching.
- `tmux.repl_pane_close`: Closing the pane, this uses `tmux pane-kill` so
  forcefully terminate whatever might be running in the REPL session.
- `tmux.repl_pass_line`:  Takes a line as a string, and send the contents to
  the REPL window. When this method is called it will always push the REPL pane
  to the foreground.
- `tmux.repl_pass_visual`: When in visual mode, pass the entire selection to
  the REPL pane.

## Additional recommendations

The [`mini.ai`][mini-ai] plugin is a very powerful method for including scopes
with the context of the tree-sitter parser. For example, if you have set up
`function` scopes to correspond to the `F` item in `mini.ai`, you can then pass
a single function to the REPL instance via the keystrokes: `vaF<leader>rp`,
where `vaF` uses [`mini.ai`][mini-ai] to set the visual selection to match the
function scope closest to the current cursor position, and the `<leader>rp`
triggers passing the visual selection to REPL.

## An example!

Below is a quick example of what it can do! Here I'm using a slightly modified
backend for `matplotlib` so that I can justify the use of `tmux` by having
in-line images be directly displayed inline!

[![Watch the video](https://raw.githubusercontent.com/yimuchen/tmux-repl.nvim/main/demo/thumbnail.png)](https://raw.githubusercontent.com/yimuchen/tmux-repl.nvim/main/demo/demo.webm)


[mini-ai]: https://github.com/echasnovski/mini.ai
[tmux]: https://github.com/tmux/tmux/wiki
