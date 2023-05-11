local tty = require("infra.tty")
local unsafe = require("infra.unsafe")
local fn = require("infra.fn")

-- todo: should be provided by emmylua-stubs.nvim
---@class gallop.WinInfo
---@field botline number
---@field topline number
---@field height number
---@field width number
---@field textoff number
---@field winbar number
---@field wincol number
---@field winrow number

local api = vim.api

local chars
do
  local n = 2
  chars = tty.read_chars(n)
  if chars == nil then error("canceled") end
end
print(chars)

-- const's
local ns = api.nvim_create_namespace("sss")

local win_id = api.nvim_get_current_win()
local bufnr = api.nvim_win_get_buf(win_id)

-- todo: zf powered fuzzy-matching
-- todo: consider utf-8 chars
local target_matcher = vim.regex([[\<]] .. chars)
-- for advancing the offset if the rest of a line starts with these chars
local advance_matcher = vim.regex([[^[^a-zA-Z0-9_]\+]])

api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

-- todo: cursor-coordinated visible region: sj, sk
local visible_region = {}
do
  assert(not vim.wo[win_id].wrap, "not supported yet")

  -- col: 0-indexed
  -- row: 1-indexed
  -- line/lnum: 0-indexed
  -- start: inclusive
  -- stop: exclusive

  --local cursor = api.nvim_win_get_cursor(win_id)
  ---@type gallop.WinInfo
  local wininfo = assert(vim.fn.getwininfo(win_id)[1])
  local leftcol = api.nvim_win_call(win_id, vim.fn.winsaveview).leftcol
  local topline = wininfo.topline - 1
  local botline = wininfo.botline - 1

  visible_region.start_line = topline
  visible_region.start_col = leftcol
  visible_region.stop_line = botline + 1
  visible_region.stop_col = leftcol + (wininfo.width - wininfo.textoff)

  do
    -- stylua: ignore
    local fmt = "leftcol=%d, topline=%d, botline=%d, width=%d, textoff=%d"
      .. "region_start=line=%d,col=%d, region_stop=line=%d,col=%d"
    local args = {
      leftcol,
      topline,
      botline,
      wininfo.width,
      wininfo.textoff,
      visible_region.start_line,
      visible_region.start_col,
      visible_region.stop_line,
      visible_region.stop_col,
    }
    vim.notify(string.format(fmt, unpack(args)))
  end
end

do -- highlight matches
  -- todo: ignore comments and string literals

  -- todo: use for sn, sp
  ---@type {[number]: number[]}
  local matches = {}
  local lineslen = unsafe.lineslen(bufnr, fn.range(visible_region.start_line, visible_region.stop_line))

  for lnum = visible_region.start_line, visible_region.stop_line - 1 do
    matches[lnum] = {}
    local offset = visible_region.start_col
    local eol = math.min(visible_region.stop_col, lineslen[lnum])
    while offset < eol do
      local col_start, col_stop
      do -- match next target
        local rel_start, rel_stop = target_matcher:match_line(bufnr, lnum, offset, eol)
        if rel_start == nil then break end
        col_start = rel_start + offset
        col_stop = rel_stop + offset
      end
      do -- advance offset
        local adv_start, adv_stop = advance_matcher:match_line(bufnr, lnum, col_stop, eol)
        if adv_start ~= nil then
          offset = adv_stop + col_stop
        else
          offset = col_stop
        end
        assert(offset >= col_stop)
      end
      api.nvim_buf_add_highlight(bufnr, ns, "Search", lnum, col_start, col_stop)
      table.insert(matches[lnum], col_start)
      table.insert(matches[lnum], col_stop)
    end
  end
end
