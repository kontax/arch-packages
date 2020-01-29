" Bootstrap vim files within directory

" Loop through config files and source them
for s:fname in split(glob(Dot('/modules/*.vim')), '\n')
    execute 'source' s:fname
endfor
