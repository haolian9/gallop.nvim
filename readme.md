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
* limited support repeat via `,` and `;`
* 支持自然码双拼

## limits, undefined behaviors
* it does not work in neovide/nvim-qt due to tty:read()
* using it on a &foldenable window is an UB

## status
* just works
* feature-complete

## prerequisites
* linux
* nvim 0.10.*
* haolian9/infra.nvim

## usage

here's my personal setting

```
do --repeats
  m.n(",", function() require("infra.repeats").rhs_comma() end)
  m.n(";", function() require("infra.repeats").rhs_semicolon() end)
end

do --gallop
  do
    local last_chars
    m({ "n", "x" }, "s", function() last_chars = require("gallop").words(2, last_chars, true) or last_chars end)
  end

  do
    local last_chars
    m({ "n", "x" }, "S", function() last_chars = require("gallop").shuangpin(last_chars, true) or last_chars end)
  end

  m({ "n", "x" }, "gl", function() require("gallop").lines() end)
  m({ "n", "x" }, "go", function() require("gallop").cursorcolumn() end)

  m.o("s", "<cmd>lua require'gallop'.strings(2)<cr>")
end
```
