an opinionated jump motion implementation

https://user-images.githubusercontent.com/6236829/238657940-b8c6fc48-49d0-4337-8ac9-8066b6274f63.mp4

## design choices
* be minimal: no callback, no back-forth, no {treesitter,lsp}-backed
* only for the viewport of currently window
* every label is a printable ascii char
* when labels are not enough, the rest targets will be discarded silently
* no excluding comments and string literals
* no caching collected targets
* respect jumplist

## limits, undefined behaviors
* it does not work in neovide/nvim-qt due to tty:read()
* using it on a &foldenable window is an UB

## status
* just works
* feature-complete

## prerequisites
* linux
* nvim 0.9.*
* haolian9/infra.nvim

## usage

here's my personal setting

```
do
  local last_chars
  m("gallop words",  { "n", "x" }, "s",   function() last_chars = require("gallop").words(2, last_chars) or last_chars end)
  m("gallop strs",   { "n", "x" }, [[\]], function() last_chars = require("gallop").strings(2, last_chars) or last_chars end)
  m("gallop lines",  { "n", "x" }, "gl",  function() require("gallop").lines() end)
  m("gallop curcol", { "n", "x" }, "go",  function() require("gallop").cursorcolumn() end)

  m.o("gallop operator", "s", "<cmd>lua require'gallop'.strings(2)<cr>")
end
```
