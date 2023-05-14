-- about the name
--
-- whoa. nice car, man.
-- yeah. it gets me from A to B.
--
-- oh, darn. all this horsepower and no room to gallop.
--

-- design choices
-- * only for the the visible region of currently window
-- * every label a printable ascii char
-- * when there is no enough labels, targets will be discarded
-- * be minimal: no callback, no back-forth
-- * opininated pattern for targets
-- * no excluding comments and string literals
-- * no cache
--

local tty = require("infra.tty")
local unsafe = require("infra.unsafe")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("gallop", vim.log.levels.DEBUG)
local ex = require("infra.ex")

---@class gallop.VisibleRegion
---@field start_line number 0-indexed, inclusive
---@field start_col  number 0-indexed, inclusive
---@field stop_line  number 0-indexed, exclusive
---@field stop_col   number 0-indexed, exclusive

---@class gallop.Target
---@field lnum      number 0-indexed
---@field col_start number 0-indexed, inclusive
---@field col_stop  number 0-indexed, exclusive

local api = vim.api

local Labels = {}
do
  local list = {}
  local dict = {}
  do
    local str = table.concat({
      "asdfjkl;" .. "gh" .. "qwertyuiop" .. "zxcvbnm",
      ",./'[" .. "]1234567890-=",
      "ASDFJKL" .. "GH" .. "WERTYUIOP" .. "ZXCVBNM",
    }, "")
    for i = 1, #str do
      local char = string.sub(str, i, i)
      list[i] = char
      dict[char] = i
    end
  end

  function Labels.index(label) return dict[label] end
  function Labels.iter() return fn.iterate(list) end
end

local ns = api.nvim_create_namespace("gallop")
-- todo: nvim bug: nvim_set_hl(0) vs `hi clear`; see https://github.com/neovim/neovim/issues/23589
api.nvim_set_hl(ns, "GallopStop", { ctermfg = 15, ctermbg = 8, cterm = { bold = true } })

-- for advancing the offset if the rest of a line starts with these chars
local advance_matcher = vim.regex([[^[^a-zA-Z0-9_]\+]])

---@param winid any
---@return gallop.VisibleRegion
local function resolve_visible_region(winid)
  assert(not vim.wo[winid].wrap, "not supported yet")

  local region = {}

  local wininfo = assert(vim.fn.getwininfo(winid)[1])
  local leftcol = api.nvim_win_call(winid, vim.fn.winsaveview).leftcol
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
---@param target_matcher vim.Regex
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

---@param winid number
---@param bufnr number
---@param targets gallop.Target[]
local function place_labels(winid, bufnr, targets)
  api.nvim_win_set_hl_ns(winid, ns)

  local label_iter = Labels.iter()
  for k, m in ipairs(targets) do
    local label = label_iter()
    if label == nil then return jelly.warn("ran out of labels: %d", #targets - k) end
    api.nvim_buf_set_extmark(bufnr, ns, m.lnum, m.col_start, {
      virt_text = { { label, "GallopStop" } },
      virt_text_pos = "overlay",
    })
  end
end

---@param winid number
---@param bufnr number
---@param region gallop.VisibleRegion
local function clear_labels(winid, bufnr, region)
  api.nvim_win_set_hl_ns(winid, 0)
  api.nvim_buf_clear_namespace(bufnr, ns, region.start_col, region.stop_line)
end

---@param winid number
---@param target gallop.Target
local function goto_target(winid, target) api.nvim_win_set_cursor(winid, { target.lnum + 1, target.col_start }) end

---@param nchar? number read >=n chars from user
---@param chars? string ascii chars
---@return string? chars used for the search if no error occurs
return function(nchar, chars)
  nchar = nchar or 2

  if chars == nil then chars = tty.read_chars(nchar) end
  if #chars == 0 then return jelly.debug("canceled") end

  local target_matcher
  do
    -- behave like &smartcase
    local pattern
    if string.find(chars, "%u") then
      pattern = [[\C\<]] .. chars
    else
      pattern = [[\c\<]] .. chars
    end
    target_matcher = vim.regex(pattern)
  end

  local winid = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)

  local visible_region = resolve_visible_region(winid)
  local targets = collect_targets(bufnr, visible_region, target_matcher)

  if #targets == 0 then return jelly.debug("no target found") end
  if #targets == 1 then return goto_target(winid, targets[1]) end

  place_labels(winid, bufnr, targets)
  ex("redraw")

  local ok, err = pcall(function()
    local target
    do
      local chosen_label = tty.read_chars(1)
      if #chosen_label == 0 then return jelly.info("chose no label") end
      local target_index = Labels.index(chosen_label)
      if target_index == nil then return jelly.warn("unknown label: %s", chosen_label) end
      target = targets[target_index]
      if target == nil then return jelly.warn("chosen label has no corresponding target") end
    end
    goto_target(winid, target)
  end)
  clear_labels(winid, bufnr, visible_region)
  if not ok then error(err) end

  return chars
end
