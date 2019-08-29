call plug#begin('~/.vim/plugged')

" http://vimawesome.com/

" Language
Plug 'pangloss/vim-javascript'
Plug 'othree/yajs.vim'
Plug 'isRuslan/vim-es6'
Plug 'derekwyatt/vim-scala'
Plug 'scrooloose/syntastic'

" Completion
" Code display
Plug 'eslint/eslint'
" Integrations

" Interface
Plug 'altercation/vim-colors-solarized'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'ctrlpvim/ctrlp.vim'


" Commands
" Other
Plug 'bronson/vim-trailing-whitespace'
Plug 'jistr/vim-nerdtree-tabs'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }

" Add plugins to runtimepath
call plug#end()

set background=dark
colorscheme solarized

" line number
set number
set relativenumber

" airline tabline
let g:airline#extensions#tabline#enabled = 1

" syntastic
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

" eslint syntax check for javascript files
let g:syntastic_javascript_checkers = ['eslint']

" tab width
set tabstop=2 softtabstop=0 expandtab shiftwidth=2 smarttab
