local M = {}

M.log = function(ref, lb, format)
  return vim.fn.system({ "git", "log", "--reverse", "-n" .. lb, "--pretty=format:" .. format, ref })
end

M.rel_head = function(arg)
  if arg:match("^~%d+$") then return "HEAD" .. arg end
  return arg
end

M.refresh_head = function()
  local ref = vim.fn.system("git rev-parse --abbrev-ref HEAD")
  if vim.v.shell_error ~= 0 then
    vim.g.gitutils_head = ""
    return
  end
  local ref_clean = vim.trim(ref)
  local title = M.log("HEAD", 1, "%s")
  vim.g.gitutils_head = title .. " -> " .. ref_clean
end

return M
