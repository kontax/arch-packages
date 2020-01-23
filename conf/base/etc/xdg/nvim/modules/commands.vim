" Custom autocmd commands

augroup configgroup
    autocmd!

    " Intent methods
    autocmd FileType python setlocal foldmethod=indent

    " Comment out lines
    autocmd FileType python nnoremap <buffer> <leader>c I#<esc>
    autocmd FileType python vnoremap <silent> <leader>c :s/^/#/<cr>:noh<cr>
    autocmd FileType cs     nnoremap <buffer> <leader>c I//<esc>
    autocmd FileType cs     vnoremap <silent> <leader>c :s/^/\/\//<cr>:noh<cr>
augroup END
