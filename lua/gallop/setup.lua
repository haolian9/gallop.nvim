local api = vim.api
local blackmagic = require("infra.blackmagic")

local ran = false
return function()
  -- stylua: ignore
  if ran then return else ran = true end

  blackmagic.set_global_hl(function() api.nvim_set_hl(0, "GallopStop", { ctermfg = 15, ctermbg = 8, cterm = { bold = true } }) end)
end
