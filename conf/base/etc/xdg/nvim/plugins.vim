" This is the main plugin list, sourced by modules/plugins.vim
" Configuration goes in the appropriate modules/plugins/*.vim file.
" So configuration for tmux.vim would go in modules/plugins/tmux.vim.vim

Plug 'ctrlpvim/ctrlp.vim'
Plug 'sjl/gundo.vim'
"Plug 'Valloric/YouCompleteMe'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'bling/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'tpope/vim-fugitive'

" Language servers
let g:coc_global_extensions = [
            \ 'coc-json'
            \ 'coc-rls'
            \ 'coc-jedi'
            \ 'coc-sh'
            \ ]
