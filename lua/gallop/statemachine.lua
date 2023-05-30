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
local jelly = require("infra.jellyfish")("gallop.statemachine", vim.log.levels.DEBUG)
local ex = require("infra.ex")
local prefer = require("infra.prefer")
local jumplist = require("infra.jumplist")

local facts = require("gallop.facts")

---@class gallop.Viewport
---@field start_line number 0-indexed, inclusive
---@field start_col  number 0-indexed, inclusive
---@field stop_line  number 0-indexed, exclusive
---@field stop_col   number 0-indexed, exclusive

---@class gallop.Target
---@field lnum      number 0-indexed
---@field col_start number 0-indexed, inclusive
---@field col_stop  number 0-indexed, exclusive

local api = vim.api

---@param winid any
---@return gallop.Viewport
local function resolve_viewport(winid)
  assert(not prefer.wo(winid, "wrap"), "not supported yet")

  local viewport = {}

  local wininfo = assert(vim.fn.getwininfo(winid)[1])
  local leftcol = api.nvim_win_call(winid, vim.fn.winsaveview).leftcol
  local topline = wininfo.topline - 1
  local botline = wininfo.botline - 1

  viewport.start_line = topline
  viewport.start_col = leftcol
  viewport.stop_line = botline + 1
  viewport.stop_col = leftcol + (wininfo.width - wininfo.textoff)

  return viewport
end

---@param bufnr number
---@param viewport gallop.Viewport
---@param target_matcher vim.Regex
---@return gallop.Target[]
local function collect_targets(bufnr, viewport, target_matcher)
  local targets = {}
  local lineslen = unsafe.lineslen(bufnr, fn.range(viewport.start_line, viewport.stop_line))

  for lnum = viewport.start_line, viewport.stop_line - 1 do
    local offset = viewport.start_col
    local eol = math.min(viewport.stop_col, lineslen[lnum])
    while offset < eol do
      local col_start, col_stop
      do -- match next target
        local rel_start, rel_stop = target_matcher:match_line(bufnr, lnum, offset, eol)
        if rel_start == nil then break end
        col_start = rel_start + offset
        col_stop = rel_stop + offset
      end
      do -- advance offset
        local adv_start, adv_stop = facts.advance_matcher:match_line(bufnr, lnum, col_stop, eol)
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
  api.nvim_win_set_hl_ns(winid, facts.ns)

  local label_iter = facts.labels.iter()
  for k, m in ipairs(targets) do
    local label = label_iter()
    if label == nil then return jelly.warn("ran out of labels: %d", #targets - k) end
    api.nvim_buf_set_extmark(bufnr, facts.ns, m.lnum, m.col_start, {
      virt_text = { { label, "GallopStop" } },
      virt_text_pos = "overlay",
    })
  end
end

---@param winid number
---@param bufnr number
---@param viewport gallop.Viewport
local function clear_labels(winid, bufnr, viewport)
  api.nvim_win_set_hl_ns(winid, 0)
  api.nvim_buf_clear_namespace(bufnr, facts.ns, viewport.start_col, viewport.stop_line)
end

---@param targets gallop.Target[]
---@param label string
---@return gallop.Target?
local function label_to_target(targets, label)
  local target_index = facts.labels.index(label)
  -- user input a unexpected key
  if target_index == nil then return end
  local target = targets[target_index]
  -- user input a unused label
  if target == nil then return end
  return target
end

---@param winid number
---@param target gallop.Target
local function goto_target(winid, target)
  do
    local row, col = unpack(api.nvim_win_get_cursor(winid))
    if target.lnum + 1 == row and target.col_start == col then return end
  end

  jumplist.push_here()

  api.nvim_win_set_cursor(winid, { target.lnum + 1, target.col_start })
end

---@param chars string @ascii characters
return function(chars)
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

  local viewport = resolve_viewport(winid)
  local targets = collect_targets(bufnr, viewport, target_matcher)

  if #targets == 0 then return jelly.debug("no target found") end
  if #targets == 1 then return goto_target(winid, targets[1]) end

  place_labels(winid, bufnr, targets)
  ex("redraw")

  local ok, err = pcall(function()
    -- keep asking user for a valid label
    while true do
      local chosen_label = tty.read_chars(1)
      if #chosen_label == 0 then return jelly.info("chose no label") end
      local target = label_to_target(targets, chosen_label)
      -- can not redraw here, since showing message in cmdline will move the cursor and wait an `<enter>`
      if target ~= nil then return goto_target(winid, target) end
    end
  end)
  clear_labels(winid, bufnr, viewport)
  if not ok then error(err) end
end
