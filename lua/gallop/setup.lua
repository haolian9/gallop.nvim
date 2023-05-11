local api = vim.api

local ran = false
return function()
  -- stylua: ignore
  if ran then return else ran = true end

  api.nvim_set_hl(0, "GallopStop", { ctermfg = 15, ctermbg = 8, cterm = { bold = true } })
end
