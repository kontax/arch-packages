" Get the directory that the current config files reside in
let g:nvim_config_root = expand('<sfile>:p:h')

" Wraps paths to make them relative to this directory
function! Dot(path)
    return g:nvim_config_root . '/' . a:path
endfunction

" Source customised config files
execute 'source ' Dot('/bootstrap.vim')
