an opinionated, crude jump motion implementation

## features/limits
* everything happends in the visible region of current window
* every target is labeled by only one char, so some of them will be discarded
* no callback, no back-forth
* target matching pattern: `\<` .. chars_you_pressed
* `<esc>` to cancel, `<space>` to stop collect chars

## prerequisites
* linux
* nvim 0.9.*
* haolian9/infra.nvim

## usage
* `require'gallop.setup'()` # necessary setup
* `require'gallop'(3)` # it will ask you 3 chars to find targets, then ask you a label where to move cursor to

## how is it implemented
* use tty.read_chars() to get user input without changing cursor position
* use vim.regex() to find targets
* use nvim_buf_set_extmark() to show labels
