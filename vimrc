call plug#begin('~/.vim/plugged')

" http://vimawesome.com/"

" Language
Plug 'pangloss/vim-javascript'
Plug 'derekwyatt/vim-scala'
Plug 'scrooloose/syntastic'

" Completion
" Code display
" Integrations
" Interface
Plug 'altercation/vim-colors-solarized'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Commands
" Other
Plug 'bronson/vim-trailing-whitespace'
Plug 'jistr/vim-nerdtree-tabs'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }




" Add plugins to &runtimepath
call plug#end()

set background=dark
colorscheme solarized
