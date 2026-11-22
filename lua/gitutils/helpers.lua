local M = {}

M.root = function()
  return vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]
end

M.log = function(rev, lb, format, path)
  local cmd = { "git", "log", "--reverse", "-n" .. lb, "--pretty=format:" .. format, rev }
  if path then vim.list_extend(cmd, { "--", path }) end
  return vim.fn.system(cmd)
end

M.prompt_rev = function(msg, callback)
  vim.ui.input({ prompt = M.log("HEAD", 5, "%h %s%d") .. "\n" .. msg }, function(rev)
    if not rev or rev == "" then return end
    if rev:match("^~%d+$") then rev = "HEAD" .. rev end
    callback(rev)
  end)
end

M.refresh_head = function()
  local ref = vim.fn.system("git rev-parse --abbrev-ref HEAD")
  if vim.v.shell_error ~= 0 then
    vim.g.gitutils_head = ""
    return
  end
  local title = M.log("HEAD", 1, "%s")
  vim.g.gitutils_head = title .. " -> " .. vim.trim(ref)
end

return M
