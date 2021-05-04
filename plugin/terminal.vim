if !exists("g:vim_term_termwin")
  let g:vim_term_termwin = v:false
endif

if !exists("g:vim_term_rows")
  let g:vim_term_rows=16
endif

if !exists("g:vim_term_shell")
  " shell used to run commands with :Term, it should be interactive shell.
  " Most of the shells support `-i` and `-c` flags.
  if has("win64") || has("win95")
    let g:vim_term_shell = []
  else
    let g:vim_term_shell = [&shell, "-i", "-c"]
  endif
endif

com! -bang -count=0 -nargs=* Shell                :call vimterm#Shell(<q-mods>, <q-bang>, <count>, <q-args>)
com! -bang -count=0 -nargs=* -complete=file Term  :call vimterm#Term(<q-mods>, <q-bang>, <count>, vimterm#ShellParse(<q-args>, <f-args>))
com! -bang -count=0 -nargs=* -complete=file Job   :call vimterm#Term(<q-mods>, <q-bang>, <count>, vimterm#ShellParse('++hidden ++close ' . <q-args>, '++hidden', '++close', <f-args>))
if exists("g:vim_term_nixterm")
  com! -bang -nargs=* -complete=file NixTerm  :call vimterm#NixTerm(<q-mods>, <q-bang>, vimterm#ShellParse(<q-args>, <f-args>))
endif


" Turn off wrap scan option for terminal buffers, store the global option in
" 's:wrapscan' (note: 'wrapscan' is a global option, hence all the
" complexity).
let s:wrapscan = &wrapscan
fun s:ToggleWrapscan() abort
  if &buftype == 'terminal'
    noautocmd set nowrapscan
  else
    let &wrapscan = s:wrapscan
  endif
endfun

augroup VimTermWrapScan
  au!
  au BufEnter  *          call s:ToggleWrapscan()
  au OptionSet wrapscan   let s:wrapscan = v:option_new
  au OptionSet background call vimterm#ResetTerms()
augroup END
