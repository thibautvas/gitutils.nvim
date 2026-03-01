local M = {}

local gh = require("gitutils.helpers")
local rebase_state = nil

M.commit = function()
  vim.ui.input({ prompt = "Commit message: " }, function(msg)
    if not msg or msg == "" then return end
    vim.fn.system({ "git", "commit", "-m", msg })
    gh.error_interrupt("commit")
    gh.refresh_head()
  end)
end

M.amend = function()
  vim.ui.input({ prompt = "Amend message: " }, function(msg)
    if not msg or msg == "" then return end
    vim.fn.system({ "git", "commit", "--amend", "-m", msg })
    gh.error_interrupt("amend")
    gh.refresh_head()
  end)
end

M.extend = function()
  vim.fn.system({ "git", "commit", "--amend", "--no-edit" })
  gh.error_interrupt("extend")
end

M.checkout = function()
  vim.ui.input({ prompt = gh.log(5, "%h %s%d") .. "\nCheckout: " }, function(hash)
    if not hash or hash == "" then return end
    vim.fn.system({ "git", "checkout", hash })
    gh.error_interrupt("checkout")
    vim.cmd("checktime")
    gh.refresh_head()
  end)
end

M.rebase = function()
  vim.ui.input({ prompt = gh.log(5, "%h %s%d") .. "\nRebase from: " }, function(hash)
    if not hash or hash == "" then return end

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
      on_exit = gh.rebase_exit(rebase_state),
    })
  end)
end

M.continue = function()
  if not rebase_state then
    vim.notify("No rebase in progress", vim.log.levels.WARN)
    return
  end
  vim.fn.jobstart({ "git", "rebase", "--continue" }, {
    env = rebase_state.env,
    on_exit = gh.rebase_exit(rebase_state),
  })
end

M.setup = function()
  if vim.fn.executable("git") == 0 then
    vim.notify("git not found", vim.log.levels.ERROR)
    return
  end

  local subcmds = {
    amend = M.amend,
    checkout = M.checkout,
    commit = M.commit,
    extend = M.extend,
    rebase = M.rebase,
    continue = M.continue,
  }

  vim.api.nvim_create_user_command("Gitutils", function(opts)
    local sub = opts.args
    if not subcmds[sub] then
      vim.notify("Gitutils unknown subcommand: " .. sub, vim.log.levels.ERROR)
      return
    end
    subcmds[sub]()
  end, {
    nargs = 1,
    complete = function()
      return vim.tbl_keys(subcmds)
    end,
  })
end

return M
