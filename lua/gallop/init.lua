-- features:
-- todo: zf powered fuzzy-matching
-- todo: consider utf-8 chars
-- todo: ignore comments and string literals

local tty = require("infra.tty")
local unsafe = require("infra.unsafe")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("gallop", vim.log.levels.DEBUG)

---@class gallop.WinInfo
---@field botline number
---@field topline number
---@field height  number
---@field width   number
---@field textoff number
---@field winbar  number
---@field wincol  number
---@field winrow  number

---@class gallop.VisibleRegion
---@field start_line number 0-indexed, inclusive
---@field start_col  number 0-indexed, inclusive
---@field stop_line  number 0-indexed, exclusive
---@field stop_col   number 0-indexed, exclusive

---@class gallop.Target
---@field lnum number 0-indexed
---@field col_start number 0-indexed, inclusive
---@field col_stop number 0-indexed, exclusive

local api = vim.api

local Labels = {}
do
  local list = {}
  do
    local str = table.concat({
      "asdfjkl;" .. "gh" .. "qwertyuiop" .. "zxcvbnm",
      ",./'[" .. "]1234567890-=",
      "ASDFJKL" .. "GH" .. "WERTYUIOP" .. "ZXCVBNM",
    }, "")
    for i = 1, #str do
      table.insert(list, string.sub(str, i, i))
    end
  end

  function Labels.as_index(label)
    for k, v in pairs(list) do
      if v == label then return k end
    end
  end

  function Labels.iter() return fn.iterate(list) end
end

local ns = api.nvim_create_namespace("gallop")
-- for advancing the offset if the rest of a line starts with these chars
local advance_matcher = vim.regex([[^[^a-zA-Z0-9_]\+]])

---@param win_id any
---@return gallop.VisibleRegion
local function resolve_visible_region(win_id)
  assert(not vim.wo[win_id].wrap, "not supported yet")

  local region = {}

  ---@type gallop.WinInfo
  local wininfo = assert(vim.fn.getwininfo(win_id)[1])
  local leftcol = api.nvim_win_call(win_id, vim.fn.winsaveview).leftcol
  local topline = wininfo.topline - 1
  local botline = wininfo.botline - 1

  region.start_line = topline
  region.start_col = leftcol
  region.stop_line = botline + 1
  region.stop_col = leftcol + (wininfo.width - wininfo.textoff)

  return region
end

---@param bufnr number
---@param visible_region gallop.VisibleRegion
---@param target_matcher Regex
---@return gallop.Target[]
local function collect_targets(bufnr, visible_region, target_matcher)
  local targets = {}
  local lineslen = unsafe.lineslen(bufnr, fn.range(visible_region.start_line, visible_region.stop_line))

  for lnum = visible_region.start_line, visible_region.stop_line - 1 do
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
      table.insert(targets, { lnum = lnum, col_start = col_start, col_stop = col_stop })
    end
  end

  return targets
end

---@param bufnr number
---@param targets gallop.Target[]
local function place_labels(bufnr, targets)
  local label_iter = Labels.iter()
  for k, m in ipairs(targets) do
    local label = label_iter()
    if label == nil then
      jelly.warn("ran out of labels: %d", #targets - k)
      break
    end
    api.nvim_buf_set_extmark(bufnr, ns, m.lnum, m.col_start, {
      virt_text = { { label, "GallopStop" } },
      virt_text_pos = "overlay",
    })
  end
end

---@param bufnr number
---@param region gallop.VisibleRegion
local function clear_labels(bufnr, region) api.nvim_buf_clear_namespace(bufnr, ns, region.start_col, region.stop_line) end

---@param win_id number
---@param target gallop.Target
local function goto_target(win_id, target) api.nvim_win_set_cursor(win_id, { target.lnum + 1, target.col_start }) end

return function(nchar)
  nchar = nchar or 2

  local win_id = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(win_id)

  local target_matcher
  do
    local chars = tty.read_chars(nchar)
    if #chars == 0 then return jelly.debug("canceled") end
    target_matcher = vim.regex([[\<]] .. chars)
  end

  local visible_region = resolve_visible_region(win_id)
  local targets = collect_targets(bufnr, visible_region, target_matcher)

  if #targets == 0 then return jelly.debug("no target found") end
  if #targets == 1 then return goto_target(win_id, targets[1]) end

  place_labels(bufnr, targets)
  vim.cmd.redraw()

  local choice = tty.read_chars(1)
  if #choice == 0 then return clear_labels(bufnr, visible_region) end

  local target = assert(targets[Labels.as_index(choice)])
  goto_target(win_id, target)
  clear_labels(bufnr, visible_region)
end
