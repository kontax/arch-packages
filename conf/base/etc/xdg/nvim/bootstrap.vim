" Bootstrap vim files within directory

" Get the directory that the current config files reside in
let g:nvim_config_root = expand('<sfile>:p:h')

" Wraps paths to make them relative to this directory
function! Dot(path)
    return g:nvim_config_root . '/' . a:path
endfunction

" Loop through config files and source them
for s:fname in split(glob(Dot('/modules/*.vim')), '\n')
    execute 'source' s:fname
endfor
