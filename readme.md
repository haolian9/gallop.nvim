an opinionated, crude jump motion implementation

<<<<<<< HEAD
## design choices
* only for the the visible region of currently window
* every label a printable ascii char
* when there is no enough labels, targets will be discarded
* be minimal: no callback, no back-forth
* opininated pattern for targets
* no exclude comments and string literals
||||||| parent of dc708f4 (sync with upstream)
## features/limits
* everything happends in the visible region of current window
* every target is labeled by only one char, so some of them will be discarded
* no callback, no back-forth
* target matching pattern: `\<` .. chars_you_pressed
* `<esc>` to cancel, `<space>` to stop collect chars
=======
design choices
* only for the the visible region of currently window
* every label is a printable ascii char
* when there is no enough labels, targets will be discarded
* be minimal: no callback, no back-forth
* opininated pattern for targets
* no excluding comments and string literals
* no cache

>>>>>>> dc708f4 (sync with upstream)

## prerequisites
* linux
* nvim 0.9.*
* haolian9/infra.nvim

## usage
<<<<<<< HEAD
`require'gallop.setup'()`: necessary setup

`require'gallop'(3)`
1. it asks you 3 chars which will be used to find targets
2. then it asks you a label where you want to go
||||||| parent of dc708f4 (sync with upstream)
* `require'gallop.setup'()` # necessary setup
* `require'gallop'(3)` # it will ask you 3 chars to find targets, then ask you a label where to move cursor to
=======
* `require'gallop.setup'()` # necessary setup
* `require'gallop'(3)` # ask user 3 chars to match
* `require'gallop'(nil, 'hello')'` # use give chars to match
>>>>>>> dc708f4 (sync with upstream)

<<<<<<< HEAD
## how is it implemented
||||||| parent of dc708f4 (sync with upstream)
## how is it implemented
* use tty.read_chars() to get user input without changing cursor position
=======
## how does it work
>>>>>>> dc708f4 (sync with upstream)
* use vim.regex() to find targets
* use nvim_buf_set_extmark() to show labels
