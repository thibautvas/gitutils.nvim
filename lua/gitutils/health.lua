local M = {}

local function check_nvim()
  vim.health.start("gitutils.nvim: nvim")
  if vim.fn.has("nvim-0.11") ~= 1 then
    vim.health.error("Neovim 0.11 or newer is required", {
      "vim.fs.relpath is used to run the diff commands",
    })
    return
  end
  vim.health.ok(string.format("nvim version: %s", vim.version()))
end

local function check_git()
  vim.health.start("gitutils.nvim: git")
  if vim.fn.executable("git") ~= 1 then
    vim.health.error("git not found in $PATH")
    return
  end
  vim.health.ok(vim.trim(vim.fn.system({ "git", "--version" })))
end

M.check = function()
  check_nvim()
  check_git()
end

return M
