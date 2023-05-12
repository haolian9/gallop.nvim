an opinionated, crude jump motion implementation

## design choices
* only for the the visible region of currently window
* every label a printable ascii char
* when there is no enough labels, targets will be discarded
* be minimal: no callback, no back-forth
* opininated pattern for targets
* no exclude comments and string literals

## prerequisites
* linux
* nvim 0.9.*
* haolian9/infra.nvim

## usage
`require'gallop.setup'()`: necessary setup

`require'gallop'(3)`
1. it asks you 3 chars which will be used to find targets
2. then it asks you a label where you want to go

## how is it implemented
* use vim.regex() to find targets
* use nvim_buf_set_extmark() to show labels
