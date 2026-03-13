local M = {}

local gh = require("gitutils.helpers")
local diff_hash = nil

local function diff_buf(hash)
  local filepath = vim.fn.expand("%")
  if not filepath or filepath == "" then
    vim.notify("No file in buffer", vim.log.levels.WARN)
    return true
  end
  local filetype = vim.bo.filetype
  local content = vim.fn.systemlist({ "git", "show", hash .. ":" .. filepath })
  if vim.v.shell_error ~= 0 then
    if table.concat(content, "\n"):find("invalid object name") then
      vim.notify("Invalid object name", vim.log.levels.ERROR)
      return true
    end
    content = {}
  end
  local ok, err = pcall(function()
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

local function collect_diff_files(hash)
  local files = vim.fn.systemlist({ "git", "diff", "--name-only", hash })
  if vim.v.shell_error ~= 0 then
    vim.notify("Invalid object name", vim.log.levels.ERROR)
    return
  end
  local status_map = {}
  for _, line in ipairs(vim.fn.systemlist("git status --porcelain")) do
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
  local w = math.max(unpack(vim.tbl_map(string.len, files)))
  return vim.tbl_map(function(file)
    local status = next(status_map) and (status_map[file] or "  ") or ""
    return {
      filename = file,
      module = string.format("%s %-" .. w .. "s ", status, file),
      text = gh.log(file, 1, "%s"),
    }
  end, files)
end

M.diffthis = function()
  vim.ui.input({ prompt = gh.log("HEAD", 5, "%h %s%d") .. "\nDiff against: " }, function(hash)
    if not hash or hash == "" then return end
    hash = gh.rel_head(hash)
    diff_buf(hash)
  end)
end

M.diff = function()
  vim.ui.input({ prompt = gh.log("HEAD", 5, "%h %s%d") .. "\nDiff repo against: " }, function(hash)
    if not hash or hash == "" then return end
    hash = gh.rel_head(hash)
    local files, status_map = collect_diff_files(hash)
    if not files then return end
    if #files == 0 then
      vim.notify("No files to diff", vim.log.levels.WARN)
      return
    end
    diff_hash = hash
    vim.fn.setqflist(build_diff_qf(files, status_map), "r")
    vim.cmd("copen")
    vim.cmd("cfirst")
    diff_buf(hash)
  end)
end

M.qf_diff = function(dir)
  if not diff_hash or diff_hash == "" then return end
  local qf = vim.fn.getqflist({ idx = 0, size = 0 })
  if dir == "next" and qf.idx == qf.size then return end
  if dir == "prev" and qf.idx == 1 then return end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "nofile" then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.cmd("c" .. dir)
  diff_buf(diff_hash)
end

return M
