local M = {}

local gh = require("gitutils.helpers")

M.checkout = function()
  gh.prompt_rev("Checkout: ", function(hash)
    local output = vim.fn.system({ "git", "checkout", hash })
    if output:find("pathspec") and output:find("did not match") then
      vim.ui.input({ prompt = "Create branch " .. hash .. "? " }, function(yn)
        if yn ~= "y" then return end
        vim.fn.system({ "git", "checkout", "-b", hash })
      end)
    end
    if vim.v.shell_error ~= 0 then
      vim.notify("Gitutils checkout failed", vim.log.levels.ERROR)
      return
    end
    vim.cmd("checktime")
    gh.refresh_head()
  end)
end

return M
