augroup Terminal
  au!
  au TerminalOpen * if &buftype == "terminal" | setl nonu nornu nospell | endif
augroup END

fun! s:ShellBufs(termwin)
  return filter(getbufinfo(), {key, val -> getbufvar(val.bufnr, "&buftype") == "terminal" && (a:termwin || getbufvar(val.bufnr, "isShell") == v:true)})
endfun

fun! s:OpenShell(vert, argList, range, line1, line2)
  let argList = copy(a:argList)
  if a:range == 0
    let range = ""
  elseif a:range == 1
    let range = line1
  else
    let range = line1 . "," . line2
  endif
  if index(argList, "++nokill") == -1
    call add(argList, "++kill=kill")
  else
    call filter(argList, {idx, arg -> arg != "++nokill"})
  endif
  if index(argList, "++noclose") == -1
    call add(argList, "++close")
  endif
  let inTermWin = index(argList, "++termwin") >= 0
  let cwinnr = v:null
  if inTermWin
    let inTermWin = v:false
    call filter(argList, {key, arg -> split(arg, '\s*=\s*')[0] != "++termwin"})
    let cwinnr = v:null
    let win = s:FindTermWin()
    if !empty(win)
	let inTermWin = v:true
	let winnr = win.winnr
	let cwinnr = winnr()
	call add(argList, "++curwin")
	exe winnr . "wincmd w"
    endif
  endif
  let args = join(map(
	\ filter(
	  \ map(copy(argList), {idx, val -> split(val, '\s*=\s*')}),
          \ {idx, val -> s:isShellArg(val)}),
	\ {idx, val -> join(val, '=')})
	\ )
  try
    exe range . (a:vert ? "vert " : "") . "term " . args . " " . &l:shell
  catch /.*/
    echoerr v:errmsg
    return
  endtry
  if index(argList, "++hidden") != -1
    return
  endif
  let rows = s:getRows(copy(argList))
  if rows == v:null
    let rows = 16
  endif
  let b:term_rows = rows
  if rows != v:null && !a:vert && !inTermWin
    exe "resize" . rows
  endif
  if index(argList, "++curwin") == -1
    setl wfh wfw nospell
  endif
endfun

fun! s:FindTermWin()
  let tab = tabpagenr()
  for win in getwininfo()
    if win.terminal == 1 && win.tabnr == tab
      return win
    endif
  endfor
  return {}
endfun

fun! s:Shell(bang, vert, args, range, line1, line2)
  let argList = split(a:args) 
  let inTermWin = index(argList, "++termwin") != -1
  let winnr = v:null
  if inTermWin
    let win = s:FindTermWin()
    if !empty(win)
        let inTermWin = v:true
        let winnr = win.winnr
        call add(argList, "++curwin")
        exe winnr . "wincmd w"
    endif
  endif

  let bufs = s:ShellBufs(v:false)
  if empty(bufs) || a:bang == "!"
    call s:OpenShell(a:vert, argList, a:range, a:line1, a:line2)
    let b:isShell = v:true
    return
  elseif len(bufs) == 1
    let bnr = bufs[0].bufnr
    let wins = bufs[0].windows
  else
    let idx = inputlist(map(copy(bufs), {idx, buf -> printf("%2d [%3d] %s", idx + 1, buf.bufnr, bufname(buf.bufnr))}))
    if idx == 0
      return
    else
      let bnr = bufs[idx-1].bufnr
      let wins = bufs[idx-1].windows
    endif
  endif

  call filter(map(wins, {idx, winId -> win_id2win(winId)}), {idx, win -> win != 0})
  if !empty(wins)
    exe wins[0] . "wincmd w"
    call add(argList, "++curwin")
    return
  endif

  let args = join(map(
	\ filter(
	  \ map(copy(argList), {idx, val -> split(val, '\s*=\s*')}),
          \ {idx, val -> s:isArg(val)}),
	\ {idx, val -> join(val, '=')})
	\ )
 
  let rows = s:getRows(copy(argList))
  if index(argList, "++hidden") != -1
    return
  endif
  if index(argList, "++curwin") == -1
    exe (a:vert ? "vert " : "") . "sp " . args
    setl nonu nornu wfh wfw nospell
  endif
  exe "b " . bnr
  if !exists("b:term_rows")
    let b:term_rows = v:null
  endif
  if !a:vert && rows != v:null
    exe "resize" . rows
    let b:term_rows = rows
  elseif !a:vert && b:term_rows != v:null
    exe "resize " . b:term_rows 
  endif
endfun

fun! s:isShellArg(arg)
  if index(['++close', '++nokill', '++noclose', '++open', '++curwin', '++hidden', '++rows', '++cols', '++eof', '++norestore', '++kill'], a:arg[0]) != -1
    return v:true
  else
    return v:false
  endif
endfun

fun! s:isTermArg(arg)
  if s:isShellArg(a:arg) || index(['++termwin', '++notermwin', '++nokill'], a:arg[0]) != -1
    return v:true
  else
    return v:false
  endif
endfun

fun! s:isArg(arg)
  if a:arg[0] =~ '^++'
    if index(["++ff", "++enc", "++bin", "++nobin", "++bad", "++edit"], a:arg[0]) != -1
      return v:true
    else
      return v:false
    endif
  else
    return v:true
  endif
endfunc

fun! s:getRows(args)
  let rows = map(filter(map(a:args, {idx, val -> split(val, "=")}), {idx, arg -> arg[0] ==# "++rows"}), {idx, val -> val[1]})
  if len(rows) >= 1
    return rows[0]
  else
    return v:null
  endif
endfun

com! -bang -nargs=* Shell  call s:Shell(<q-bang>, v:false, <q-args>, <range>, <line1>, <line2>)
com! -bang -nargs=* VShell call s:Shell(<q-bang>, v:true,  <q-args>, <range>, <line1>, <line2>)

fun! OnTerm(cmd)
  if &buftype !=# 'terminal'
    return
  endif
  exe a:cmd
endfun

com! -nargs=+ TermDo :bufdo call OnTerm(<args>)

" todo:
" - add # pointer: `ListTerms#` jumps to previous pointer position
"   (the <c-^> key could be remapped in term window)
fun! s:ListTerms()
  let terms = filter(getbufinfo(), {key, val -> getbufvar(val.bufnr, "&buftype") == "terminal"})
  if len(terms) == 0
    return
  endif
  let idx = inputlist(map(copy(terms), {idx, buf -> printf("%2d [%3d] %s", idx + 1, buf.bufnr, bufname(buf.bufnr))}))
  if idx == 0 || idx > len(terms)
    return
  endif
  let term = terms[idx-1]
  let win = s:FindTermWin()
  if !empty(win)
    exe win.winnr . "wincmd w"
    exe "b " . term.bufnr
    setl buftype=terminal
  else
    exe "sb ". term.bufnr
    setl buftype=terminal
    setl nonu nornu nospell wfh wfw
    if !exists("b:term_rows")
      let b:term_rows = 16
    endif
    if b:term_rows != v:null
      exe "resize" . b:term_rows
    endif
  endif
endfun

fun! s:RunTerm(bang, vert, args)
    let term_args = []
    let cmd_args = []
    for arg in a:args
      if arg =~ '^++'
	call add(term_args, arg)
      else
	call add(cmd_args, arg)
      endif
    endfor
    let cmd = join(cmd_args, ' ')
    let inTermWin = index(term_args, "++termwin") >= 0
    let cwinnr = v:null
    if inTermWin
      let inTermWin = v:false
      call filter(term_args, {key, arg -> split(arg, '\s*=\s*')[0] != "++termwin"})
      let cwinnr = v:null
      let win = s:FindTermWin()
      if !empty(win)
        let inTermWin = v:true
        let winnr = win.winnr
        let cwinnr = winnr()
        call add(term_args, "++curwin")
        exe winnr . "wincmd w"
      endif
    endif
    if index(term_args, "++nokill") == -1
      call add(term_args, "++kill=kill")
    endif
    let vim_term_args = filter(copy(term_args), {idx,val -> s:isShellArg(split(val,'\s*=\s*'))})
    try
      let g:cmd = (a:vert ? "vert " : "") . "term " . join(vim_term_args, ' ') . " " . cmd
      exe (a:vert ? "vert " : "") . "term " . join(vim_term_args, ' ') . " " . cmd
    catch /.*/
      echoerr v:errmsg
      return
    endtry
    if index(term_args, "++hidden") != -1
      return
    endif
    let inCurWin = !inTermWin && index(term_args, "++curwin") >= 0
    if !inCurWin
      setl nonu nornu nospell wfh wfw
    endif
    if a:bang == "" && cwinnr != v:null
      exe cwinnr . "wincmd w"
    endif
    let rows = s:getRows(copy(term_args))
    if rows == v:null
      let rows = 16
    endif
    let b:term_rows = rows
    if !a:vert && !inTermWin && !inCurWin
      exe "resize" . rows
    endif
endfun

" Bang: also show shells
fun! s:Term(bang, vert, ...)
  if a:0 >= 1 && type(a:1) == v:t_list
    let args = a:1
  else
    let args = a:000
  endif
  if len(args)
    call s:RunTerm(a:bang, a:vert, args)
  else
    call s:ListTerms()
  endif
endfun

com! -bang -nargs=* -complete=file Term  :call s:Term(<q-bang>, v:false, <f-args>)
com! -bang -nargs=* -complete=file VTerm :call s:Term(<q-bang>, v:true,  <f-args>)

fun! s:NixTerm(bang, vert, ...)
  let args = copy(a:000)
  let nixfile = ""
  if args[0] =~# '^\f\+\.nix$'
    let nixfile = args[0]
    call remove(args, 0)
  endif

  " nix-shell options
  let nixattr = ""
  let idx = index(args, "-A")
  if idx >= 0
    let nixattr .= "-A " . args[idx + 1]
    call remove(args, idx, idx + 1)
  endif
  let idx = index(args, "--prune")
  if idx >= 0
    let nixattr .= (!empty(nixattr) ? " " : "") . "--prune"
    call remove(args, idx)
  endif
  while index(args, "--arg") >= 0
    let idx = index(args, "--arg")
    let nixattr .= (!empty(nixattr) ? " " : "") . "--arg " . args[idx+1] . " " . args[idx+2]
    call remove(args, idx, idx + 2)
  endwhile
  while index(args, "--argstr") >= 0
    let idx = index(args, "--argstr")
    let nixattr .= (!empty(nixattr) ? " " : "") . "--argstr " . args[idx+1] . " " . args[idx+2]
    call remove(args, idx, idx + 2)
  endwhile

  let shell=&shell
  if len(filter(copy(args), {idx, val -> !s:isTermArg(split(val,'\s*=\s*'))})) > 0
    " has command
    let &shell="nix-shell " . nixfile . " " . nixattr . " --run"
  else
    call extend(args, ["nix-shell", nixattr])
  endif
  let g:args = args
  call s:Term(a:bang, a:vert, args)
  let &shell=shell
endfun

if exists("g:terminal_nix_term")
  com! -bang -nargs=* -complete=file NixTerm  :call s:NixTerm(<q-bang>, v:false, <f-args>)
  com! -bang -nargs=* -complete=file VNixTerm :call s:NixTerm(<q-bang>, v:true,  <f-args>)
endif
