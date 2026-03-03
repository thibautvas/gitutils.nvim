{
  description = "clean nvim with gitutils.nvim";

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
          customRC = ''
            lua << EOF
              vim.opt.number = true
              vim.opt.signcolumn = "yes"

              local gu = require("gitutils")
              gu.setup()

              vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
                pattern = "*",
                callback = require("gitutils.helpers").refresh_head
              })

              vim.opt.rulerformat = '%66(%{g:gitutils_head}%= %l,%c%)'

              vim.keymap.set("n", "<space>hc", gu.commit, { desc = "Gitutils commit" })
              vim.keymap.set("n", "<space>he", gu.extend, { desc = "Gitutils extend" })
              vim.keymap.set("n", "<space>hb", gu.checkout, { desc = "Gitutils checkout" })
              vim.keymap.set("n", "<space>hx", gu.rebase, { desc = "Gitutils interactive rebase" })
              vim.keymap.set("n", "<space>hv", gu.continue, { desc = "Gitutils rebase continue" })

              vim.keymap.set("n", "<space>hg", gu.diff, { desc = "Gitutils diff repo" })
              vim.keymap.set("n", "]g", function()
                gu.qf_diff("next")
              end, { desc = "Gitutils next diff" })
              vim.keymap.set("n", "[g", function()
                gu.qf_diff("prev")
              end, { desc = "Gitutils prev diff" })
            EOF
          '';

          neovimConfig = pkgs.neovimUtils.makeNeovimConfig {
            inherit customRC;
            plugins = with pkgs.vimPlugins; [
              gitutils-nvim
              gitsigns-nvim
            ];
          };

          customNvim = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped neovimConfig;

        in
        {
          default = customNvim;
        }
      );
    };
}
