local tty = require("infra.tty")
local unsafe = require("infra.unsafe")
local fn = require("infra.fn")

local api = vim.api

local chars
do
  local n = 2
  chars = tty.read_chars(n)
  if #chars < n then error("canceled") end
end
print(chars)

-- const's
local ns = api.nvim_create_namespace("sss")

local win_id = api.nvim_get_current_win()
local bufnr = api.nvim_win_get_buf(win_id)

-- todo: zf powered fuzzy-matching
local matcher = vim.regex([[\<]] .. chars)

---@class wormhole.WinInfo
---@field botline number
---@field topline number
---@field height number
---@field width number
---@field textoff number
---@field winbar number
---@field wincol number
---@field winrow number

api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

-- [start, stop) -> inclusive, exclusive
local visible_region = {}
do
  -- todo: cursor-coordinated visible region
  assert(not vim.wo[win_id].wrap, "not supported yet")

  -- col: 0-indexed
  -- row: 1-indexed
  -- line/lnum: 0-indexed
  -- start: inclusive
  -- stop: exclusive

  --local cursor = api.nvim_win_get_cursor(win_id)
  ---@type wormhole.WinInfo
  local wininfo = assert(vim.fn.getwininfo(win_id)[1])
  local leftcol = api.nvim_win_call(win_id, vim.fn.winsaveview).leftcol
  local topline = wininfo.topline - 1
  local botline = wininfo.botline - 1

  visible_region.start_line = topline
  visible_region.start_col = leftcol
  visible_region.stop_line = botline + 1
  visible_region.stop_col = wininfo.width - wininfo.textoff - leftcol - 1 + 1

  vim.notify(assert(vim.inspect(visible_region)))
end

do -- highlight matches
  -- todo: ignore comments and string literals

  ---@type {[number]: number[]}
  local matches = {}
  -- todo: what about `~` lines in the bottom
  local lineslen = unsafe.lineslen(bufnr, fn.range(visible_region.start_line, visible_region.stop_line))
  vim.notify(assert(vim.inspect(lineslen)))

  for lnum = visible_region.start_line, visible_region.stop_line - 1 do
    matches[lnum] = {}
    local offset = visible_region.start_col
    local eol = math.min(visible_region.stop_col, lineslen[lnum])
    -- todo: offset 避让上次匹配到的单词
    while true do
      local col_start, col_stop
      do
        local rel_start, rel_stop = matcher:match_line(bufnr, lnum, offset, eol)
        if rel_start == nil then break end
        col_start = rel_start + offset
        col_stop = rel_stop + offset
      end
      offset = col_stop
      api.nvim_buf_add_highlight(bufnr, ns, "Search", lnum, col_start, col_stop)
      table.insert(matches[lnum], col_start)
      table.insert(matches[lnum], col_stop)
    end
  end

  vim.notify(assert(vim.inspect(matches)))
end
