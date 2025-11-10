local M = {}

local ropes = require("string.buffer")
local new_table = require("table.new")

local ascii = require("infra.ascii")
local buflines = require("infra.buflines")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("gallop.target_collectors", "info")
local logging = require("infra.logging")
local unsafe = require("infra.unsafe")
local utf8 = require("infra.utf8")

local log = logging.newlogger("gallop.target_collectors", "info")

local facts = require("gallop.facts")

do
  -- for advancing the offset if the rest of a line starts with these chars
  local advance_matcher = vim.regex([[\v^[a-zA-Z0-9_]+]])

  ---@param bufnr number
  ---@param viewport gallop.Viewport
  ---@param target_regex vim.Regex
  ---@return gallop.Target[]
  local function collect(bufnr, viewport, target_regex)
    local targets = {}
    local lineslen = itertools.todict(unsafe.linelen_iter(bufnr, itertools.range(viewport.start_line, viewport.stop_line)))

    for lnum in itertools.range(viewport.start_line, viewport.stop_line) do
      local offset = viewport.start_col
      local eol = math.min(viewport.stop_col, lineslen[lnum])
      while offset < eol do
        local col_start, col_stop
        do -- match next target
          local rel_start, rel_stop = target_regex:match_line(bufnr, lnum, offset, eol)
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

  do
    local rope = ropes.new()

    ---@param bufnr integer
    ---@param viewport gallop.Viewport
    ---@param chars string @ascii only by design
    ---@return gallop.Target[], string? @(targets, pattern-being-used)
    function M.word_head(bufnr, viewport, chars)
      local pattern
      do
        rope:put([[\M]])
        --&smartcase
        rope:put(string.find(chars, "%u") and [[\C]] or [[\c]])
        --word bound
        if ascii.is_letter(string.sub(chars, 1, 1)) then rope:put([[\<]]) end
        rope:put(chars)

        pattern = rope:get()
        jelly.debug("pattern='%s'", pattern)
      end

      return collect(bufnr, viewport, vim.regex(pattern)), pattern
    end
  end

  do
    local rope = ropes.new()

    ---@param bufnr integer
    ---@param viewport gallop.Viewport
    ---@param chars string @ascii only by design
    ---@return gallop.Target[], string? @(targets, pattern-being-used)
    function M.string(bufnr, viewport, chars)
      local pattern
      do
        rope:put([[\M]])
        --&smartcase
        rope:put(string.find(chars, "%u") and [[\C]] or [[\c]])
        rope:put(chars)

        pattern = rope:get()
        jelly.debug("pattern='%s'", pattern)
      end

      return collect(bufnr, viewport, vim.regex(pattern)), pattern
    end
  end
end

---@param viewport gallop.Viewport
---@return gallop.Target[], string? @(targets, pattern-being-used)
function M.line_head(viewport)
  local targets = {}
  for lnum in itertools.range(viewport.start_line, viewport.stop_line) do
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
  for lnum in itertools.range(viewport.start_line, viewport.stop_line) do
    table.insert(targets, { lnum = lnum, col_start = start, col_stop = stop, carrier = "win", col_offset = offset })
  end
  return targets, nil
end

do
  ---credits: the shuangpin data is generated from https://github.com/mozillazg/pinyin-data/blob/v0.15.0/pinyin.txt

  local map

  ---@return {string: {string: true}}
  local function get_rune_shuangpin_map()
    if map then return map end

    map = new_table(50562, 0) --`$ wc -l data/shuangpin.data`
    --todo: memory expiration
    for line in io.lines(facts.shuangpin_file) do
      local pin = line:sub(1, #"ab")
      local rune = line:sub(#"ab " + 1)
      if map[rune] == nil then map[rune] = {} end
      map[rune][pin] = true
    end
    return map
  end

  local function get_visible_line(bufnr, lnum, col_start, col_stop)
    --todo: *perf* do it in c/zig realm
    --todo: batch
    --todo: partial rune
    local max_cells = col_stop - col_start
    local stop = col_start + (col_stop - col_start) * 3 --assume all for utf8 runes
    local line = assert(buflines.partial_line(bufnr, lnum, col_start, stop))
    log.debug("visible max_cells=%s line=[%s]", max_cells, line)
    local cell_count, byte_count = 0, 0
    for char in utf8.iterate(line) do
      byte_count = byte_count + #char
      local step = #char > 1 and 2 or 1
      cell_count = cell_count + step
      if cell_count == max_cells then break end
      if cell_count > max_cells then
        cell_count = cell_count - step
        byte_count = byte_count - #char
        break
      end
    end
    assert(cell_count <= max_cells)
    log.debug("cell-count=%s slice-bytes=%s", cell_count, byte_count)

    return line:sub(1, byte_count)
  end

  ---@param bufnr integer
  ---@param viewport gallop.Viewport
  ---@param chars string @ascii only by design
  ---@return gallop.Target[], string? @(targets, pattern-being-used)
  function M.shuangpin(bufnr, viewport, chars) --
    assert(chars:match("^[a-z][a-z]$"), "invalid shuangpin")

    local targets = {}

    local rune_to_shuangpins = get_rune_shuangpin_map()

    --todo: *perf* 当前以字匹配字码，如果以字码找字会不会更快?
    --todo: *perf* 缓存？

    log.debug("viewport line=[%s,%s) col=[%s,%s)", viewport.start_line, viewport.stop_line, viewport.start_col, viewport.stop_col)

    for lnum in itertools.range(viewport.start_line, viewport.stop_line) do
      local line = assert(get_visible_line(bufnr, lnum, viewport.start_col, viewport.stop_col))
      local offset = viewport.start_col
      log.debug("scanning line=%s [%s]", lnum, line)

      for rune in utf8.iterate(line, true) do
        local col_start = offset
        local col_stop = col_start + #rune
        offset = offset + #rune

        local pins = rune_to_shuangpins[rune]
        if pins and pins[chars] then --
          table.insert(targets, { lnum = lnum, col_start = col_start, col_stop = col_stop, carrier = "buf", col_offset = 0 })
        end
      end
    end

    jelly.debug("码: %s, matches: %s", chars, targets)

    return targets, chars
  end
end

return M
