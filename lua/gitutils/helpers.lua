local M = {}

M.log = function(lb, format)
  return vim.fn.system({ "git", "log", "--reverse", "-n" .. lb, "--pretty=format:" .. format })
end

M.refresh_head = function()
  local ref = vim.fn.system({ "git", "rev-parse", "--abbrev-ref", "HEAD" })
  if vim.v.shell_error ~= 0 then
    vim.g.gitutils_head = ""
    return
  end
  local ref_clean = vim.trim(ref)
  local title = M.log(1, "%s")
  vim.g.gitutils_head = title .. " -> " .. ref_clean
end

M.error_interrupt = function(subcmd)
  if vim.v.shell_error ~= 0 then
    vim.notify(string.format("Gitutils %s failed", subcmd), vim.log.levels.ERROR)
    return
  end
end

M.rebase_exit = function(rebase_state)
  local function on_exit(_, code)
    if code ~= 0 then
      vim.notify("Rebase interrupted with code " .. code, vim.log.levels.ERROR)
      return
    end
    vim.schedule(function()
      vim.cmd("checktime")
      M.refresh_head()
      -- TODO: check from subdir
      local in_progress = vim.fn.isdirectory(".git/rebase-merge") == 1
      if in_progress then
        vim.notify("Rebase in progress")
        return
      end
      vim.fn.delete(rebase_state.script)
      vim.fn.delete(rebase_state.fifo)
      vim.api.nvim_del_autocmd(rebase_state.au_id)
      rebase_state = nil
      vim.notify("Rebase done")
    end)
  end
  return on_exit
end

return M
