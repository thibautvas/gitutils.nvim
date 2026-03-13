local M = {}

for fn, mod in pairs({
  checkout = "checkout",
  commit   = "commit",
  amend    = "commit",
  extend   = "commit",
  diffthis = "diff",
  diff     = "diff",
  qf_diff  = "diff",
  rebase   = "rebase",
  continue = "rebase",
}) do
  M[fn] = function(...)
    return require("gitutils.actions." .. mod)[fn](...)
  end
end

M.setup = function()
  if vim.fn.executable("git") == 0 then
    vim.notify("git not found", vim.log.levels.ERROR)
    return
  end

  local subcmds = {}
  for _, key in ipairs({
    "checkout",
    "commit",
    "amend",
    "extend",
    "diffthis",
    "diff",
    "rebase",
    "continue",
  }) do
    subcmds[key] = M[key]
  end

  vim.api.nvim_create_user_command("Gitutils", function(opts)
    local sub = opts.args
    if not subcmds[sub] then
      vim.notify("Gitutils unknown subcommand: " .. sub, vim.log.levels.ERROR)
      return
    end
    subcmds[sub]()
  end, {
    nargs = 1,
    force = true,
    complete = function()
      return vim.tbl_keys(subcmds)
    end,
  })
end

return M
