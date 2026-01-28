local helpers = require("codecompanion.interactions.chat.tools.builtin.helpers")
local log = require("codecompanion.utils.log")

local fmt = string.format

---@class CodeCompanion.Tool.DdgrSearch.Result
---@field title string
---@field url string
---@field abstract string

---Run ddgr and return parsed results
---@param action { query: string, max_results?: number }
---@param opts table
---@return { status: "success"|"error", data: CodeCompanion.Tool.DdgrSearch.Result[]|string }
local function ddgr_search(action, opts)
  opts = opts or {}

  if not action or not action.query or action.query == "" then
    return { status = "error", data = "Query parameter is required and cannot be empty" }
  end

  if vim.fn.executable("ddgr") ~= 1 then
    return { status = "error", data = "ddgr is not installed or not in PATH" }
  end

  local max_results = action.max_results or opts.max_results or 10
  if type(max_results) ~= "number" or max_results < 1 then
    max_results = 10
  end

  -- Best-effort: ddgr supports JSON output in recent versions.
  -- We use --num (results per page) and rely on the first page only.
  local cmd = {
    "ddgr",
    "--json",
    "--num",
    tostring(max_results),
    action.query,
  }

  log:debug("[Ddgr Search Tool] Running command: %s", table.concat(cmd, " "))

  local result = vim
    .system(cmd, {
      text = true,
      timeout = opts.timeout or 30000,
    })
    :wait()

  if result.code ~= 0 then
    local err = (result.stderr and vim.trim(result.stderr) ~= "") and result.stderr or result.stdout
    err = (err and vim.trim(err) ~= "") and err or "Unknown error"
    return { status = "error", data = fmt("ddgr failed: %s", err:match("^[^\n]*") or err) }
  end

  local stdout = result.stdout or ""
  if vim.trim(stdout) == "" then
    return { status = "success", data = {} }
  end

  local ok, decoded = pcall(vim.json.decode, stdout)
  if not ok then
    return { status = "error", data = fmt("Failed to parse ddgr JSON output: %s", decoded) }
  end

  -- ddgr may return either an array, or an object containing an array.
  local items
  if vim.islist(decoded) then
    items = decoded
  elseif type(decoded) == "table" then
    items = decoded.results or decoded.items or decoded
  end

  if type(items) ~= "table" then
    return { status = "success", data = {} }
  end

  local out = {}
  for _, item in ipairs(items) do
    if #out >= max_results then
      break
    end

    if type(item) == "table" then
      local url = item.url or item.link or ""
      local title = item.title or item.heading or url
      local abstract = item.abstract or item.snippet or item.description or ""

      if url ~= "" then
        table.insert(out, {
          title = tostring(title or ""),
          url = tostring(url),
          abstract = tostring(abstract or ""),
        })
      end
    end
  end

  return { status = "success", data = out }
end

---@class CodeCompanion.Tool.DdgrSearch: CodeCompanion.Tools.Tool
return {
  name = "ddgr_search",
  cmds = {
    ---Execute the search command
    ---@param self CodeCompanion.Tool.DdgrSearch
    ---@param args table The arguments from the LLM's tool call
    ---@param input? any
    ---@return { status: "success"|"error", data: any }
    function(self, args, input)
      return ddgr_search(args, self.tool.opts)
    end,
  },
  schema = {
    type = "function",
    ["function"] = {
      name = "ddgr_search",
      description = "Searches the web via ddgr (DuckDuckGo from the terminal) and returns results.",
      parameters = {
        type = "object",
        properties = {
          query = {
            type = "string",
            description = "The query to search the web for.",
          },
          max_results = {
            type = "number",
            description = "How many results to return. Defaults to 10.",
          },
        },
        required = { "query" },
        additionalProperties = false,
      },
    },
  },
  output = {
    ---Returns the command that will be executed
    ---@param self CodeCompanion.Tool.DdgrSearch
    ---@param args { tools: CodeCompanion.Tools }
    ---@return string
    cmd_string = function(self, args)
      return self.args.query or ""
    end,

    ---Message shown during approval
    ---@param self CodeCompanion.Tool.DdgrSearch
    ---@param tools CodeCompanion.Tools
    ---@return nil|string
    prompt = function(self, tools)
      local max_results = self.args.max_results or self.tool.opts.max_results or 10
      return fmt("Search the web for `%s` (top %d)?", self.args.query, max_results)
    end,

    ---Rejection message back to the LLM
    ---@param self CodeCompanion.Tool.DdgrSearch
    ---@param tools CodeCompanion.Tools
    ---@param cmd table
    ---@param opts table
    ---@return nil
    rejected = function(self, tools, cmd, opts)
      local message = "The user rejected the ddgr_search tool"
      opts = vim.tbl_extend("force", { message = message }, opts or {})
      helpers.rejected(self, tools, cmd, opts)
    end,

    ---@param self CodeCompanion.Tool.DdgrSearch
    ---@param tools CodeCompanion.Tools
    ---@param cmd table
    ---@param stdout table
    success = function(self, tools, cmd, stdout)
      local chat = tools.chat

      local results = stdout[1]
      if type(results) ~= "table" then
        results = {}
      end

      local llm_payload = vim.json.encode({
        query = cmd.query,
        results = results,
      })

      local user_output = fmt("Searched for `%s`, %d result(s)", cmd.query, #results)
      chat:add_tool_output(self, llm_payload, user_output)
    end,

    ---@param self CodeCompanion.Tool.DdgrSearch
    ---@param tools CodeCompanion.Tools
    ---@param cmd table
    ---@param stderr table
    error = function(self, tools, cmd, stderr)
      local chat = tools.chat
      local errors = vim.iter(stderr):flatten():join("\n")
      chat:add_tool_output(self, fmt("Error searching for `%s`:\n%s", self.args.query or "", errors))
    end,
  },
}
