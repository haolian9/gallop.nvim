an opinionated jump motion implementation

https://user-images.githubusercontent.com/6236829/238657940-b8c6fc48-49d0-4337-8ac9-8066b6274f63.mp4

## design choices
* only for the viewport of currently window
* every label is one printable ascii char
* when there are not enough labels, targets will be discarded silently
* be minimal: no callback, no back-forth, no {treesitter,lsp}-backed
* no excluding comments and string literals
* opininated pattern for targets
* no cache
* respect jumplist

## limits, undefined behaviors
* it does not work in neovide/nvim-qt due to tty:read()
* using it on a &foldenable window is an UB

## status
* it just works on my machine (tm)
* it is feature-frozen

## prerequisites
* linux
* nvim 0.9.*
* haolian9/infra.nvim

## usage

here's my personal setting

```
do
  local last_chars
  m({ "n", "x" }, "s", function() last_chars = require("gallop").words(2, last_chars) or last_chars end)
  m({ "n", "x" }, "S", function() require("gallop").lines() end)
end
```
