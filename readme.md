an opinionated, crude jump motion implementation

https://user-images.githubusercontent.com/6236829/238657940-b8c6fc48-49d0-4337-8ac9-8066b6274f63.mp4

## design choices
* only for the the visible region of currently window
* every label is a printable ascii char
* when there is no enough labels, targets will be discarded
* be minimal: no callback, no back-forth
* opininated pattern for targets
* no excluding comments and string literals
* no cache

## prerequisites
* linux
* nvim 0.9.*
* haolian9/infra.nvim

## usage
* take a look at `require'gallop'()`
* my personal seting

```
do
  local last_chars
  nmap("s", function() last_chars = require("gallop")(2, last_chars) or last_chars end)
  nmap("S", function()
    if last_chars == nil then return jelly.warn("no previous search") end
    require("gallop")(nil, last_chars)
  end)
end
```


## how does it work
* use vim.regex() to find targets
* use nvim_buf_set_extmark() to show labels
