local M = {}

local fn = require("infra.fn")
local unsafe = require("infra.unsafe")

do
  -- for advancing the offset if the rest of a line starts with these chars
  local advance_matcher = vim.regex([[^[^a-zA-Z0-9_]\+]])

  ---@param bufnr number
  ---@param viewport gallop.Viewport
  ---@param chars string
  ---@return gallop.Target[]
  function M.word_head(bufnr, viewport, chars)
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
        table.insert(targets, { lnum = lnum, col_start = col_start, col_stop = col_stop })
      end
    end

    return targets
  end
end

---@param viewport gallop.Viewport
---@return gallop.Target[]
function M.line_head(viewport)
  local targets = {}
  for lnum in fn.range(viewport.start_line, viewport.stop_line) do
    table.insert(targets, { lnum = lnum, col_start = 0, col_stop = 1 })
  end
  return targets
end

return M
