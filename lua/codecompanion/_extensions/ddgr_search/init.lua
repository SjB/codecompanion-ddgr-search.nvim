local M = {}

local current_opts = {
  max_results = 10,
  timeout = 30000,
  require_approval_before = true,
  require_cmd_approval = true,
}

function M.setup(opts)
  current_opts = vim.tbl_deep_extend("force", current_opts, opts or {})
  local cc_config = require("codecompanion.config")
  local tools_config = cc_config.interactions.chat.tools
  tools_config.ddgr_search = {
    callback = "codecompanion._extensions.ddgr_search.ddgr_search",
    description = "Search the web for a given query via ddgr",
    enabled = function()
      return vim.fn.executable("ddgr") == 1
    end,
    opts = current_opts,
  }
end

return M
