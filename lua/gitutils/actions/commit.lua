local M = {}

local gh = require("gitutils.helpers")

M.commit = function()
  vim.ui.input({ prompt = "Commit message: " }, function(msg)
    if not msg or msg == "" then return end
    vim.fn.system({ "git", "commit", "-m", msg })
    if vim.v.shell_error ~= 0 then
      vim.notify("Gitutils commit failed", vim.log.levels.ERROR)
      return
    end
    gh.refresh_head()
  end)
end

M.amend = function()
  vim.ui.input({ prompt = "Amend message: " }, function(msg)
    if not msg or msg == "" then return end
    vim.fn.system({ "git", "commit", "--amend", "-m", msg })
    if vim.v.shell_error ~= 0 then
      vim.notify("Gitutils amend failed", vim.log.levels.ERROR)
      return
    end
    gh.refresh_head()
  end)
end

M.extend = function()
  vim.fn.system("git commit --amend --no-edit")
  if vim.v.shell_error ~= 0 then
    vim.notify("Gitutils extend failed", vim.log.levels.ERROR)
    return
  end
end

return M
