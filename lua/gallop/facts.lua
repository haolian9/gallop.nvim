local M = {}

local fn = require("infra.fn")
local api = vim.api

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

  M.labels = {
    index = function(label) return dict[label] end,
    iter = function() return fn.iter(list) end,
  }
end

do
  M.label_ns = api.nvim_create_namespace("gallop.labels")
  api.nvim_set_hl(0, "GallopStop", { ctermfg = 15, ctermbg = 8, cterm = { bold = true } })
end

return M
