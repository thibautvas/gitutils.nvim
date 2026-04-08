{
  description = "gitutils.nvim";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          gitutils-nvim = pkgs.vimUtils.buildVimPlugin {
            name = "gitutils.nvim";
            src = ./.;
          };

          luaRcContent = ''
            vim.g.mapleader = " "
            vim.o.wrap = false
            vim.o.number = true
            vim.o.cursorline = true
            vim.o.signcolumn = "yes"
          '';

          fromLua = config: ''
            lua << EOF
              ${config}
            EOF
          '';

          plugins = with pkgs.vimPlugins; [
            {
              plugin = gitsigns-nvim;
              config = fromLua ''
                local gs = require("gitsigns")

                for dir, keymap in pairs({
                  next = "<M-h>",
                  prev = "<M-H>",
                }) do
                  vim.keymap.set({ "n", "v" }, keymap, function()
                    gs.nav_hunk(dir, { target = "all" }, function()
                      vim.cmd("norm! zz")
                    end)
                  end, { desc = "Gitsigns " .. dir .. " hunk" })
                end

                for action, keymap in pairs({
                  stage = "<leader>ha",
                  reset = "<leader>hr",
                }) do
                  vim.keymap.set("n", keymap, gs[action .. "_hunk"], {
                    desc = "Gitsigns " .. action .. " hunk",
                  })
                  vim.keymap.set("v", keymap, function()
                    gs[action .. "_hunk"]({ vim.fn.line("."), vim.fn.line("v") })
                  end, { desc = "Gitsigns " .. action .. " hunk (visual)" })
                end

                vim.keymap.set("n", "<leader>hd", gs.preview_hunk_inline, { desc = "Gitsigns diff hunk" })

                vim.keymap.set({ "o", "x" }, "ih", gs.select_hunk, { desc = "Gitsigns select hunk" })
              '';
            }
            {
              plugin = gitutils-nvim;
              config = fromLua ''
                local gu = require("gitutils")
                gu.setup()

                vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
                  pattern = "*",
                  callback = require("gitutils.helpers").refresh_head,
                })

                vim.opt.rulerformat = "%50(%{g:gitutils_head}%= %l,%c%)"

                vim.keymap.set("n", "<leader>hc", gu.commit, { desc = "Gitutils commit" })
                vim.keymap.set("n", "<leader>he", gu.extend, { desc = "Gitutils extend" })
                vim.keymap.set("n", "<leader>hb", gu.checkout, { desc = "Gitutils checkout" })
                vim.keymap.set("n", "<leader>hx", gu.rebase, { desc = "Gitutils interactive rebase" })
                vim.keymap.set("n", "<leader>hv", gu.continue, { desc = "Gitutils rebase continue" })

                vim.keymap.set("n", "<leader>hf", function()
                  require("gitsigns").stage_hunk(nil, {}, gu.extend)
                end, { desc = "Gitsigns stage and Gitutils extend" })
                vim.keymap.set("v", "<leader>hf", function()
                  require("gitsigns").stage_hunk({ vim.fn.line("."), vim.fn.line("v") }, {}, gu.extend)
                end, { desc = "Gitsigns stage and Gitutils extend" })

                vim.keymap.set("n", "<leader>ht", gu.diffthis, { desc = "Gitutils diff buffer" })
                vim.keymap.set("n", "<leader>hg", gu.diff, { desc = "Gitutils diff repo" })
                vim.keymap.set("n", "]g", function()
                  gu.qf_diff("next")
                end, { desc = "Gitutils next diff" })
                vim.keymap.set("n", "[g", function()
                  gu.qf_diff("prev")
                end, { desc = "Gitutils prev diff" })
              '';
            }
          ];

        in
        {
          default = gitutils-nvim;
          nvim = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
            inherit luaRcContent plugins;
          };
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.nvim}/bin/nvim";
        };
      });
    };
}
