if !exists("g:vim_term_termwin")
  let g:vim_term_termwin = v:false
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

com! -bang -count=0 -nargs=* Shell  call vimterm#Shell(<q-bang>, <count>, v:false, <q-args>)
com! -bang -count=0 -nargs=* VShell call vimterm#Shell(<q-bang>, <count>, v:true,  <q-args>)

com! -bang -count=0 -nargs=* -complete=file Term  :call vimterm#Term(<q-bang>, <count>, v:false, vimterm#ShellParse(<q-args>, <f-args>))
com! -bang -count=0 -nargs=* -complete=file VTerm :call vimterm#Term(<q-bang>, <count>, v:true,  vimterm#ShellParse(<q-args>, <f-args>))

if exists("g:vim_term_nixterm")
  com! -bang -nargs=* -complete=file NixTerm  :call vimterm#NixTerm(<q-bang>, v:false, vimterm#ShellParse(<q-args>, <f-args>))
  com! -bang -nargs=* -complete=file VNixTerm :call vimterm#NixTerm(<q-bang>, v:true,  vimterm#ShellParse(<q-args>, <f-args>))
endif
