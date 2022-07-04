" Base vim settings

""" System

set showcmd                         " Display incomplete commands
set showmode                        " Display the mode you're in
set cursorline                      " Highlights the line the cursor is on

set nobackup                        " Don't make a backup before overwriting a file
set nowritebackup                   " And again
set directory=$HOME/.vim/tmp//,.    " Keep swap files in one location

set wildmenu                        " Enhance command line completion
set wildmode=list:longest           " Complete files like a shell

set binary                          " Write files as they are without changing line endings
set hidden                          " Handle multiple buffers better


""" Input

set backspace=indent,eol,start      " Intuitive backspacing
set mouse=a                         " Enable mouse scrolling


""" Search options

set ignorecase                      " Case-insensitive searching
set smartcase                       " But case-sensitive if the expression contains a capital letter

set incsearch                       " Highlight matches as you type
set hlsearch                        " Highlight matches


""" Tabs

set tabstop=4                       " Global tab width
set softtabstop=4                   " Tab in insert mode
set shiftwidth=4                    " And again, related
set expandtab                       " Use spaces instead of tabs


""" Visual

set number                          " Show line numbers
set ruler                           " Show cursor position
syntax enable                       " Enable syntax highlighting
filetype indent on                  " Filetype detection

set colorcolumn=80                  " Horizontal line at specified column
highlight ColorColumn ctermbg=7

set wrap                            " Turn on line wrapping
set scrolloff=3                     " Show 3 lines of context around the cursor

set list                            " Enable invisible characters

set visualbell                      " Flash screen on errors
set cmdheight=2                     " Extra space for messages
set signcolumn=yes                  " Always show the signcolumn
set updatetime=300                  " Reduce time for diagnostic messages
set shortmess+=c                    " Don't show ins-completion-menu messages


""" Split Windows

set splitbelow                      " Split horizontally to the bottom
set splitright                      " Split vertically to the right


""" Folding
set foldenable                      " Enable folding
set foldlevelstart=10               " Open most folds up to 10 deep
set foldnestmax=10                  " 10 nested folds max
set foldmethod=syntax               " Folds based on syntax level
