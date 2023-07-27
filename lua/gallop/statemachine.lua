-- design choices
-- * only for the the visible region of currently window
-- * every label a printable ascii char
-- * when there is no enough labels, targets will be discarded
-- * be minimal: no callback, no back-forth
-- * opininated pattern for targets
-- * no excluding comments and string literals
-- * no cache
--

local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("gallop.statemachine")
local jumplist = require("infra.jumplist")
local prefer = require("infra.prefer")
local tty = require("infra.tty")

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
---@field carrier   'buf'|'win'

local api = vim.api

---@param winid any
---@return gallop.Viewport
local function resolve_viewport(winid)
  assert(not prefer.wo(winid, "wrap"), "no support for &wrap yet")

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
---@param targets gallop.Target[]
local function place_labels(bufnr, targets)
  local label_iter = facts.labels.iter()
  for k, target in ipairs(targets) do
    local label = label_iter()
    if label == nil then return jelly.warn("ran out of labels: %d", #targets - k) end
    if target.carrier == "buf" then
      api.nvim_buf_set_extmark(bufnr, facts.label_ns, target.lnum, target.col_start, {
        virt_text = { { label, "GallopStop" } },
        virt_text_pos = "overlay",
      })
    elseif target.carrier == "win" then
      api.nvim_buf_set_extmark(bufnr, facts.label_ns, target.lnum, 0, {
        virt_text = { { label, "GallopStop" } },
        virt_text_win_col = target.col_start,
      })
    else
      error("unexpected target.carrier")
    end
  end
end

---@param bufnr number
---@param viewport gallop.Viewport
local function clear_labels(bufnr, viewport) api.nvim_buf_clear_namespace(bufnr, facts.label_ns, viewport.start_line, viewport.stop_line) end

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

---@param collect_target fun(winid: integer, bufnr: integer, viewport: gallop.Viewport)
return function(collect_target)
  local winid = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)

  local viewport = resolve_viewport(winid)
  local targets = collect_target(winid, bufnr, viewport)

  if #targets == 0 then return jelly.debug("no target found") end
  if #targets == 1 then return goto_target(winid, targets[1]) end

  place_labels(bufnr, targets)
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
  clear_labels(bufnr, viewport)
  if not ok then error(err) end
end
