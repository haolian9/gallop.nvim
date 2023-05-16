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
* `require'gallop.setup'()` # necessary setup
* `require'gallop'(3)` # ask user 3 chars to match
* `require'gallop'(nil, 'hello')'` # use given chars to match

## how does it work
* use vim.regex() to find targets
* use nvim_buf_set_extmark() to show labels
