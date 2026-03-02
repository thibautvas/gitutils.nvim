# gitutils.nvim

## Introduction

A minimal and unambitious neovim plugin designed to streamline some common git workflows,
and to make them easily accessible directly within neovim.

The goal is to provide a simple, efficient interface for typical git commands
like `git commit`, `git checkout`, and `git rebase -i`.

## Motivation

I started to write some lua lines to extend [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim),
which is a much more complete project that I very much still use and recommend.

I eventually decided to spin them off into their own plugin,
if ever someone wants to take inspiration from them.

`gitutils.nvim` is very much a byproduct of my personal use of the editor.
It is designed to complement `gitsigns.nvim`, and not replace it.
It has a decisively minimal approach to git operations inside neovim,
and it does not aim to replicate the extensive functionality of tools like lazygit or neogit,
which I have used in the past but never to their fullest extent.

## Features

- Gitutils commit: `git commit -m <msg>`
- Gitutils amend: `git commit --amend <msg>`
- Gitutils extend: `git commit --amend --no-edit`
- Gitutils checkout: `git checkout <hash>`
- Gitutils rebase: `git rebase -i <hash>`
- Gitutils continue: `git rebase --continue`

## Configuration

The above commands become available in the nvim command line when the setup function is called,
for example via:
```lua
local gu = require("gitutils)
gu.setup()
```

I have not exposed any setup option at the moment,
as this was born from the way I personally use the editor,
that might change as the project matures.

I have expose a `vim.g.gitutils_head` global variable
that I use to display the last commit message and branch at the bottom of the screen.
I have it in the ruler, I suppose others might prefer it in the status line though:
```lua
local guh = require("gitutils.helpers")
guh.refresh_head()

vim.opt.rulerformat = '%66(%{g:gitutils_head}%= %l,%c%)'
```

The first `refresh_head()` call is made to display accurate information on startup,
no doubt there are cleaner ways to initialize it but I have not explored them yet.
The functions that change the HEAD (`git commit`, `git checkout`, etc.) also call `refresh_head()`.

## Keymaps

No keymaps are included in the plugin code, they are meant to be user-defined.
As an example, this is what I currently use:
```lua
vim.keymap.set("n", "<leader>hc", gu.commit, { desc = "Gitutils commit" })
vim.keymap.set("n", "<leader>he", gu.extend, { desc = "Gitutils extend" })
vim.keymap.set("n", "<leader>hb", gu.checkout, { desc = "Gitutils checkout" })
vim.keymap.set("n", "<leader>hx", gu.rebase, { desc = "Gitutils interactive rebase" })
vim.keymap.set("n", "<leader>hv", gu.continue, { desc = "Gitutils rebase continue" })

vim.keymap.set("n", "<leader>hf", function()
  gs.stage_hunk(nil, {}, function()
    gu.extend()
  end)
end, { desc = "Gitsigns stage and Gitutils extend" })
```
