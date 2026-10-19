local M = {}

local gh = require("gitutils.helpers")

local function prompt_rev(msg, callback)
  vim.ui.input({ prompt = gh.log("HEAD", 5, "%h %s%d") .. "\n" .. msg }, function(rev)
    if rev == "" then return end
    callback(gh.rel_head(rev))
  end)
end

local function git_show(rev, filepath)
  local lines = vim.fn.systemlist({ "git", "show", rev .. ":" .. filepath })
  return vim.v.shell_error == 0 and lines or {}
end

local function scratch_buf(lines, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = filetype
  vim.bo[buf].bufhidden = "wipe"
  vim.b[buf].gitutils_diff = true
  return buf
end

local function diff_buf(rev, base)
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == "" then
    vim.notify("No file in buffer", vim.log.levels.WARN)
    return
  end
  local filepath = vim.fs.relpath(gh.root(), bufname)
  local filetype = vim.bo.filetype
  if base then
    local buf = scratch_buf(git_show(base, filepath), filetype)
    vim.b[buf].gitutils_file = bufname
    vim.api.nvim_win_set_buf(0, buf)
  end
  vim.cmd("diffthis")
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, scratch_buf(git_show(rev, filepath), filetype))
  vim.cmd("diffthis")
  vim.cmd("wincmd p")
end

local function collect_files(rev, base)
  local lines = vim.fn.systemlist({ "git", "diff", "--name-status", rev, base })
  if vim.v.shell_error ~= 0 then
    vim.notify("Diff: " .. table.concat(lines, "\n"), vim.log.levels.ERROR)
    return nil
  end
  local entries = {}
  for _, line in ipairs(lines) do
    local status, file = line:match("^(%S+)\t(.+)$")
    local filename = gh.root() .. "/" .. file
    table.insert(entries, {
      filename = filename,
      module = string.format("%s %s ", status, file),
      text = gh.log(filename, 1, "%s"),
    })
  end
  return entries
end

local function close_diff_wins()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local file = vim.b[buf].gitutils_file
    if file then
      vim.api.nvim_win_set_buf(win, vim.fn.bufadd(file))
    elseif vim.b[buf].gitutils_diff and #vim.api.nvim_tabpage_list_wins(0) > 1 then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.cmd("diffoff!")
end

M.diffthis = function()
  prompt_rev("Diff against: ", function(rev)
    close_diff_wins()
    diff_buf(rev)
  end)
end

M.diff = function(rev, base, offset)
  local function diff_repo(rev)
    local entries = collect_files(rev, base)
    if not entries then return end
    if #entries == 0 then
      vim.notify("No diff against " .. rev, vim.log.levels.WARN)
      return
    end
    close_diff_wins()
    vim.fn.setqflist({}, "r", {
      items = entries,
      context = {
        gitutils_rev = rev,
        gitutils_base = base,
        gitutils_offset = offset,
      },
    })
    vim.cmd("copen")
    vim.cmd("cfirst")
    diff_buf(rev, base)
  end
  if rev then
    diff_repo(rev)
  else
    prompt_rev("Diff repo against: ", diff_repo)
  end
end

M.diffpast = function(dir)
  local qf = vim.fn.getqflist({ context = 0 })
  local gitutils_offset = type(qf.context) == "table" and qf.context.gitutils_offset or 0
  local offset = gitutils_offset + (dir == "next" and -1 or 1)
  M.diff("HEAD~" .. offset, offset > 0 and "HEAD~" .. (offset - 1) or nil, offset)
end

M.qf_diff = function(dir)
  local cmd = ({ next = "cnext", prev = "cprev" })[dir]
  if not cmd then return end
  local qf = vim.fn.getqflist({ idx = 0, size = 0, context = 0 })
  local rev = type(qf.context) == "table" and qf.context.gitutils_rev
  if not rev then return end
  if (dir == "next" and qf.idx == qf.size) or (dir == "prev" and qf.idx == 1) then return end
  close_diff_wins()
  vim.cmd(cmd)
  diff_buf(rev, qf.context.gitutils_base)
end

return M
