local M = {}

local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("gallop.target_collectors", "info")
local unsafe = require("infra.unsafe")

do
  -- for advancing the offset if the rest of a line starts with these chars
  local advance_matcher = vim.regex([[^[^a-zA-Z0-9_]\+]])

  ---@param bufnr number
  ---@param viewport gallop.Viewport
  ---@param pattern string @vim regex pattern
  ---@return gallop.Target[]
  local function collect(bufnr, viewport, pattern)
    jelly.debug("pattern='%s'", pattern)

    local target_matcher = vim.regex(pattern)

    local targets = {}
    local lineslen = unsafe.lineslen(bufnr, fn.range(viewport.start_line, viewport.stop_line))

    for lnum in fn.range(viewport.start_line, viewport.stop_line) do
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
          local adv_start, adv_stop = advance_matcher:match_line(bufnr, lnum, col_stop, eol)
          if adv_start ~= nil then
            offset = adv_stop + col_stop
          else
            offset = col_stop
          end
          assert(offset >= col_stop)
        end
        table.insert(targets, { lnum = lnum, col_start = col_start, col_stop = col_stop, carrier = "buf", col_offset = 0 })
      end
    end

    return targets
  end

  ---according to `:h magic`
  ---@param str string
  ---@return string
  local function escaped(str) return vim.fn.escape(str, [[.$*~\/]]) end

  ---@param bufnr integer
  ---@param viewport gallop.Viewport
  ---@param chars string @ascii only by design
  ---@return gallop.Target[], string? @(targets, pattern-being-used)
  function M.word_head(bufnr, viewport, chars)
    local parts = {}
    do
      --word bound
      local c0 = string.byte(string.sub(chars, 1, 1))
      if (c0 >= 97 and c0 <= 122) or (c0 >= 65 and c0 <= 90) then table.insert(parts, 1, [[\<]]) end

      --&smartcase
      if string.find(chars, "%u") then
        table.insert(parts, 1, [[\C]])
      else
        table.insert(parts, 1, [[\c]])
      end

      table.insert(parts, escaped(chars))
    end

    local pattern = table.concat(parts, "")

    return collect(bufnr, viewport, pattern), pattern
  end

  ---@param bufnr integer
  ---@param viewport gallop.Viewport
  ---@param chars string @ascii only by design
  ---@return gallop.Target[], string? @(targets, pattern-being-used)
  function M.string(bufnr, viewport, chars)
    local parts = {}
    do
      --&smartcase
      if string.find(chars, "%u") then
        table.insert(parts, 1, [[\C]])
      else
        table.insert(parts, 1, [[\c]])
      end

      table.insert(parts, escaped(chars))
    end

    local pattern = table.concat(parts, "")

    return collect(bufnr, viewport, pattern), pattern
  end
end

---@param viewport gallop.Viewport
---@return gallop.Target[], string? @(targets, pattern-being-used)
function M.line_head(viewport)
  local targets = {}
  for lnum in fn.range(viewport.start_line, viewport.stop_line) do
    table.insert(targets, { lnum = lnum, col_start = 0, col_stop = 1, carrier = "buf", col_offset = 0 })
  end
  return targets, nil
end

---@param viewport gallop.Viewport
---@param screen_col integer @see virtcol
---@return gallop.Target[], string? @(targets, pattern-being-used)
function M.cursorcolumn(viewport, screen_col)
  local offset = viewport.start_col
  local start = screen_col
  local stop = screen_col + 1

  local targets = {}
  for lnum in fn.range(viewport.start_line, viewport.stop_line) do
    table.insert(targets, { lnum = lnum, col_start = start, col_stop = stop, carrier = "win", col_offset = offset })
  end
  return targets, nil
end

return M
