local M = {}

local fn = require("infra.fn")
local api = vim.api

M.labels = {}
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

  function M.labels.index(label) return dict[label] end
  function M.labels.iter() return fn.iter(list) end
end

do
  M.ns = api.nvim_create_namespace("gallop")
  -- todo: nvim bug: nvim_set_hl(0) vs `hi clear`; see https://github.com/neovim/neovim/issues/23589
  api.nvim_set_hl(M.ns, "GallopStop", { ctermfg = 15, ctermbg = 8, cterm = { bold = true } })
end

-- for advancing the offset if the rest of a line starts with these chars
M.advance_matcher = vim.regex([[^[^a-zA-Z0-9_]\+]])

return M
