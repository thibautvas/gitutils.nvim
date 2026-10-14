local M = {}

local gh = require("gitutils.helpers")
local diff_hash = nil
local diff_target, diff_offset = nil, nil

local function diff_buf(hash, target)
  local bufname = vim.api.nvim_buf_get_name(0)
  if not bufname or bufname == "" then
    vim.notify("No file in buffer", vim.log.levels.WARN)
    return true
  end
  local repo_root = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]
  local filepath = vim.fs.relpath(repo_root, bufname)
  local filetype = vim.bo.filetype
  local content = vim.fn.systemlist({ "git", "show", hash .. ":" .. filepath })
  if vim.v.shell_error ~= 0 then
    if table.concat(content, "\n"):find("invalid object name") then
      vim.notify("Invalid object name", vim.log.levels.ERROR)
      return true
    end
    content = {}
  end
  local target_content = {}
  if target then
    target_content = vim.fn.systemlist({ "git", "show", target .. ":" .. filepath })
    if vim.v.shell_error ~= 0 then target_content = {} end
  end
  local ok, err = pcall(function()
    if target then
      local tbuf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, tbuf)
      vim.api.nvim_buf_set_lines(tbuf, 0, -1, false, target_content)
      vim.bo[tbuf].filetype = filetype
      vim.bo[tbuf].bufhidden = "wipe"
      vim.b[tbuf].gitutils_file = bufname
    end
    vim.cmd("diffthis")
    vim.cmd("vsplit")
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
    vim.bo[buf].filetype = filetype
    vim.bo[buf].bufhidden = "wipe"
    vim.cmd("diffthis")
    vim.cmd("wincmd p")
  end)
  if not ok then
    vim.notify("Gitutils diff failed: " .. tostring(err), vim.log.levels.ERROR)
  end
  return ok
end

local function collect_diff_files(hash, target)
  local files = vim.fn.systemlist({ "git", "diff", "--name-only", hash, target })
  if vim.v.shell_error ~= 0 then
    vim.notify("Invalid object name", vim.log.levels.ERROR)
    return
  end
  local status_map = {}
  for _, line in ipairs(target and {} or vim.fn.systemlist("git status --porcelain")) do
    local status = line:sub(1, 2)
    local file = line:sub(4)
    status_map[file] = status
    if not vim.tbl_contains(files, file) then
      table.insert(files, file)
    end
  end
  return files, status_map
end

local function build_diff_qf(files, status_map)
  local root = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]
  local w = math.max(unpack(vim.tbl_map(string.len, files)))
  return vim.tbl_map(function(file)
    local filename = root .. "/" .. file
    local status = next(status_map) and (status_map[file] or "  ") or ""
    return {
      filename = filename,
      module = string.format("%s %s ", status, file),
      text = gh.log(filename, 1, "%s"),
    }
  end, files)
end

local function close_diff_wins()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.b[buf].gitutils_file then
      vim.api.nvim_win_set_buf(win, vim.fn.bufadd(vim.b[buf].gitutils_file))
    elseif vim.bo[buf].buftype == "nofile" then
      vim.api.nvim_win_close(win, true)
    end
  end
end

M.diffthis = function()
  vim.ui.input({ prompt = gh.log("HEAD", 5, "%h %s%d") .. "\nDiff against: " }, function(hash)
    if not hash or hash == "" then return end
    hash = gh.rel_head(hash)
    diff_buf(hash)
  end)
end

M.diff = function(rev, target, offset)
  local input = rev and function(_, cb) cb(rev) end or vim.ui.input
  input({ prompt = gh.log("HEAD", 5, "%h %s%d") .. "\nDiff repo against: " }, function(hash)
    if not hash or hash == "" then return end
    hash = gh.rel_head(hash)
    local files, status_map = collect_diff_files(hash, target)
    if not files then return end
    if #files == 0 then
      vim.notify("No files to diff", vim.log.levels.WARN)
      return
    end
    if diff_hash then close_diff_wins() end
    diff_hash, diff_target, diff_offset = hash, target, offset
    vim.fn.setqflist(build_diff_qf(files, status_map), "r")
    vim.cmd("copen")
    vim.cmd("cfirst")
    diff_buf(hash, target)
  end)
end

M.diffpast = function(dir)
  local offset = (diff_offset or 0) + (dir == "next" and -1 or 1)
  if offset < 0 then return end
  M.diff("HEAD~" .. offset, offset > 0 and "HEAD~" .. (offset - 1) or nil, offset)
end

M.qf_diff = function(dir)
  if not diff_hash or diff_hash == "" then return end
  local qf = vim.fn.getqflist({ idx = 0, size = 0 })
  if dir == "next" and qf.idx == qf.size then return end
  if dir == "prev" and qf.idx == 1 then return end
  close_diff_wins()
  vim.cmd("c" .. dir)
  diff_buf(diff_hash, diff_target)
end

return M
