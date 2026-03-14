local M = {}

local gh = require("gitutils.helpers")

local function git_commit(opts, msg, desc)
  local cmd = { "git", "commit", "-m", msg }
  if desc then vim.list_extend(cmd, { "-m", desc }) end
  if opts then vim.list_extend(cmd, opts) end
  vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("Gitutils commit failed", vim.log.levels.ERROR)
    return
  end
  gh.refresh_head()
end

local function commit_with_flags(opts)
  local status = vim.fn.system("git diff --staged --name-status"):gsub("\t", " ")
  vim.ui.input({ prompt = status .. "Commit message: " }, function(msg)
    if not msg or msg == "" then return end
    if msg:sub(-1) == "!" then -- commit desc call
      local title = msg:sub(1, -2)
      vim.ui.input({ prompt = "Commit description: " }, function(desc)
        if not desc or desc == "" then return end
        git_commit(opts, title, desc)
      end)
    else
      git_commit(opts, msg, nil)
    end
  end)
end

M.commit = function() commit_with_flags() end
M.amend = function() commit_with_flags({ "--amend" }) end

M.extend = function()
  vim.fn.system("git commit --amend --no-edit")
  if vim.v.shell_error ~= 0 then
    vim.notify("Gitutils extend failed", vim.log.levels.ERROR)
    return
  end
end

return M
