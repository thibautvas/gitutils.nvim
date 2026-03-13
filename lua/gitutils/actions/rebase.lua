local M = {}

local gh = require("gitutils.helpers")
local rebase_state = nil

local function rebase_exit(state)
  return function(_, code)
    if code ~= 0 then
      vim.notify("Rebase interrupted with code " .. code, vim.log.levels.ERROR)
      return
    end
    vim.schedule(function()
      vim.cmd("checktime")
      gh.refresh_head()
      -- TODO: check from subdir
      local in_progress = vim.fn.isdirectory(".git/rebase-merge") == 1
      if in_progress then
        vim.notify("Rebase in progress")
        return
      end
      vim.fn.delete(state.script)
      vim.fn.delete(state.fifo)
      vim.api.nvim_del_autocmd(state.au_id)
      rebase_state = nil
      vim.notify("Rebase done")
    end)
  end
end

M.rebase = function()
  vim.ui.input({ prompt = gh.log("HEAD", 5, "%h %s%d") .. "\nRebase from: " }, function(hash)
    if not hash or hash == "" then return end
    hash = gh.rel_head(hash)

    local server = vim.v.servername
    if not server or server == "" then return end

    local fifo = vim.fn.tempname()
    vim.fn.system({ "mkfifo", fifo })

    local script = vim.fn.tempname() .. ".sh"
    local f = assert(io.open(script, "w"))
    f:write(string.format(
      "#!/bin/sh\nnvim --server '%s' --remote \"$1\"\ncat '%s' > /dev/null\n",
      server, fifo))
    f:close()
    vim.fn.system({ "chmod", "+x", script })

    local env = {
      GIT_SEQUENCE_EDITOR = script,
      GIT_EDITOR = script,
    }

    local au_id = vim.api.nvim_create_autocmd("BufUnload", {
      pattern = {
        "*/git-rebase-todo",
        "*/COMMIT_EDITMSG",
      },
      callback = function()
        vim.fn.jobstart({ "sh", "-c", "echo done > " .. vim.fn.shellescape(fifo) })
      end
    })

    rebase_state = { fifo = fifo, script = script, env = env, au_id = au_id }

    vim.fn.jobstart({ "git", "rebase", "-i", hash }, {
      env = env,
      on_exit = rebase_exit(rebase_state),
    })
  end)
end

M.continue = function()
  if not rebase_state then
    vim.notify("No rebase in progress", vim.log.levels.WARN)
    return
  end
  vim.fn.jobstart("git rebase --continue", {
    env = rebase_state.env,
    on_exit = rebase_exit(rebase_state),
  })
end

return M
