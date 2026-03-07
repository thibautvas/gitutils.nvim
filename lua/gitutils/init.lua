local M = {}

local gh = require("gitutils.helpers")
local rebase_state = nil
local diff_hash = nil

M.commit = function()
  gh.prompt_action(
    "commit",
    "Commit message: ",
    function(msg)
      vim.fn.system({ "git", "commit", "-m", msg })
    end,
    gh.refresh_head
  )
end

M.amend = function()
  gh.prompt_action(
    "amend",
    "Amend message: ",
    function(msg)
      vim.fn.system({ "git", "commit", "--amend", "-m", msg })
    end,
    gh.refresh_head
  )
end

M.extend = function()
  vim.fn.system("git commit --amend --no-edit")
  if vim.v.shell_error ~= 0 then
    vim.notify("Gitutils extend failed", vim.log.levels.ERROR)
  end
end

M.checkout = function()
  gh.prompt_action(
    "checkout",
    gh.log("HEAD", 5, "%h %s%d") .. "\nCheckout: ",
    function(hash)
      local output = vim.fn.system({ "git", "checkout", hash })
      if output:find("pathspec") and output:find("did not match") then
        vim.ui.input({ prompt = "Create branch " .. hash .. "? " }, function(yn)
          if yn ~= "y" then return end
          vim.fn.system({ "git", "checkout", "-b", hash })
        end)
      end
    end,
    function()
      vim.cmd("checktime")
      gh.refresh_head()
    end
  )
end

M.rebase = function()
  gh.prompt_action(
    "rebase",
    gh.log("HEAD", 5, "%h %s%d") .. "\nRebase from: ",
    function(hash)
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
    end
  )
end

M.continue = function()
  if not rebase_state then
    vim.notify("No rebase in progress", vim.log.levels.WARN)
    return
  end
  vim.fn.jobstart("git rebase --continue", {
    env = rebase_state.env,
    on_exit = gh.rebase_exit(rebase_state),
  })
end

M.diffthis = function()
  gh.prompt_action(
    "diffthis",
    gh.log("HEAD", 5, "%h %s%d") .. "\nDiff against: ",
    function(hash)
      gh.diff_view(hash)
    end
  )
end

M.diff = function()
  gh.prompt_action(
    "diff",
    gh.log("HEAD", 5, "%h %s%d") .. "\nDiff repo against: ",
    function(hash)
      diff_hash = hash
      local files = vim.fn.systemlist({ "git", "diff", "--name-only", hash })
      local w = math.max(unpack(vim.tbl_map(string.len, files)))
      if not files or not next(files) then return end
      vim.fn.setqflist(vim.tbl_map(function(f) return {
        filename = f,
        module = string.format("%-" .. w .. "s ", f),
        text = gh.log(f, 1, "%s"),
      } end, files), "r")
      vim.cmd("copen")
      vim.cmd("cfirst")
      gh.diff_view(hash)
    end
  )
end

M.qf_diff = function(dir)
  if not diff_hash or diff_hash == "" then return end
  local qf = vim.fn.getqflist({ idx = 0, size = 0 })
  if dir == "next" and qf.idx == qf.size then return end
  if dir == "prev" and qf.idx == 1 then return end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_option(buf, "buftype") == "nofile" then
      vim.api.nvim_win_close(win, true) -- close previous diff
    end
  end
  vim.cmd("c" .. dir)
  gh.diff_view(diff_hash)
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
    diff = M.diff,
    diffthis = M.diffthis,
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
