# codecompanion-ddgr-search.nvim

A small extension for [CodeCompanion.nvim](https://github.com/olimorris/codecompanion.nvim) that adds a `ddgr_search` chat tool, backed by the `ddgr` CLI (DuckDuckGo from the terminal).

## Features

- Adds a new CodeCompanion tool: `ddgr_search`
- Runs `ddgr --json` and returns parsed results (title, url, abstract)
- Tool is automatically disabled if `ddgr` is not available in `$PATH`
- Supports limiting results via `max_results`
- Configurable timeout

## Requirements

- Neovim `0.10+` (uses `vim.system`)
- [CodeCompanion.nvim](https://github.com/olimorris/codecompanion.nvim)
- [`ddgr`](https://github.com/jarun/ddgr) installed and available on your `PATH`

## Installation

Using `lazy.nvim`:

```lua
{
  -- Replace with your repo
  "sjb/codecompanion-ddgr-search.nvim",
  dependencies = {
    "olimorris/codecompanion.nvim",
  },
  config = function()
    require("codecompanion._extensions.ddgr_search").setup({
      max_results = 10,
      timeout = 30000,
    })
  end,
}
```

## Configuration

`setup()` accepts the following options:

- `max_results` (number, default: `10`)  
  Default number of results returned when `max_results` is not provided in the tool call.

- `timeout` (number, default: `30000`)  
  Timeout in ms for the `ddgr` command.

Notes:
- The extension registers the tool at: `require("codecompanion.config").interactions.chat.tools.ddgr_search`.
- The tool is enabled only when `vim.fn.executable("ddgr") == 1`.

## Usage

In a CodeCompanion chat, call the tool:

- `ddgr_search` with:
  - `query` (string, required)
  - `max_results` (number, optional)

The tool returns a JSON payload to the LLM like:

```json
{
  "query": "neovim codecompanion tools",
  "results": [
    { "title": "...", "url": "...", "abstract": "..." }
  ]
}
```

## Tool Details

- Tool name: `ddgr_search`
- Implementation:
  - `lua/codecompanion/_extensions/ddgr_search/init.lua` (registration via `setup`)
  - `lua/codecompanion/_extensions/ddgr_search/ddgr_search.lua` (execution + output formatting)

## Troubleshooting

- If the tool never appears / is always disabled:
  - ensure `ddgr` is installed and on `PATH`
  - check `:echo executable("ddgr")` returns `1`
- If searches fail:
  - try running `ddgr --json "your query"` in a terminal to confirm your `ddgr` supports JSON output
