augroup Terminal
  au!
  au TerminalOpen * if &buftype == "terminal" | setl nonu nornu nospell | endif
augroup END

fun! s:ShellBufs(termwin)
  return filter(getbufinfo(), {key, val -> getbufvar(val.bufnr, "&buftype") == "terminal" && (a:termwin || getbufvar(val.bufnr, "isShell") == v:true)})
endfun

fun! s:ShellParse(arg, ...)
  let arg = substitute(a:arg, '++\(\w\+\)\s*=\s*', '++\1=', 'g')
if has("pythonx")
pythonx << EOF
import vim
import shlex
arg = vim.eval('arg')
vim.command("let ret=%s" % shlex.split(arg))
EOF
  return ret
else
  return a:000
endif
endfun

fun! s:ShellJoin(args)
if has("pythonx")
  return join(map(a:args, {idx, val -> escape(val, ' ')}))
else
  return join(a:args)
endif
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
          \ {idx, val -> s:IsShellArg(val)}),
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
          \ {idx, val -> s:IsArg(val)}),
	\ {idx, val -> join(val, '=')})
	\ )
 
  let rows = s:getRows(copy(argList))
  if index(argList, "++hidden") != -1
    return
  endif
  if index(argList, "++curwin") == -1
    exe (a:vert ? "vert " : "") . "sp " . args
    setl ??nonu nornu wfh wfw nospell
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

fun! s:IsShellArg(arg)
  if index(['++close', '++nokill', '++noclose', '++open', '++curwin', '++hidden', '++rows', '++cols', '++eof', '++norestore', '++kill'], a:arg[0]) != -1
    return v:true
  else
    return v:false
  endif
endfun

fun! s:IsTermArg(arg)
  if s:IsShellArg(a:arg) || index(['++termwin', '++notermwin', '++nokill'], a:arg[0]) != -1
    return v:true
  else
    return v:false
  endif
endfun

fun! s:IsArg(arg)
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

com! -nargs=+ OnTerm :bufdo call OnTerm(<args>)

fun! s:LeftAlign(s, d)
  return a:s . repeat(' ', max([a:d - len(a:s), 0]))
endfun

" todo:
" - add # pointer: `ListTerms#` jumps to previous pointer position
"   (the <c-^> key could be remapped in term window)
fun! s:ListTerms()
  let terms = filter(getbufinfo(), {key, val -> getbufvar(val.bufnr, "&buftype") == "terminal"})
  if len(terms) == 0
    return
  endif
  let idx = inputlist(map(copy(terms), {idx, buf -> printf("%2d [%3d] %s %s", idx + 1, buf.bufnr, s:LeftAlign(bufname(buf.bufnr), 10), !empty(term_gettitle(buf.bufnr)) ? "[" . term_gettitle(buf.bufnr) . "]" : "")}))
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

" map :term arguments to term_start option names
fun! s:TermArgMap(name)
  if a:name == "++rows"
    return "term_rows"
  elseif a:name == "++cols"
    return "term_cols"
  elseif a:name == "++kill"
    return "term_kill"
  elseif a:name == "++close"
    return "term_finish"
  elseif a:name == "++noclose"
    return "term_finish"
  elseif a:name == "++open"
    return "term_finish"
  elseif a:name == "++eof"
    return "eof_chars"
  else
    return a:name[2:]
  endif
endfun

fun! s:TermWin(term_args)
  let term_win = index(a:term_args, "++termwin") >= 0
  let term_winnr = v:null
  if term_win
    let term_win = v:false
    call filter(a:term_args, {key, arg -> split(arg, '\s*=\s*')[0] != "++termwin"})
    let term_winnr = v:null
    let win = s:FindTermWin()
    if !empty(win)
      let term_win = v:true
      let winnr = win.winnr
      let term_winnr = winnr()
      call add(a:term_args, "++curwin")
      exe winnr . "wincmd w"
    endif
  endif
  let idx = index(a:term_args, "++nokill")
  if idx == -1
    call add(a:term_args, "++kill=kill")
  else
    call remove(a:term_args, idx)
  endif
  return [a:term_args, term_winnr]
endfun

" split terminal arguments from the command arguments
fun! s:SplitTermArgs(args)
  let term_args = []
  let term_cmd  = []
  for arg in a:args
    if s:IsTermArg(split(arg, '\s*=\s*'))
      call add(term_args, arg)
    else
      call add(term_cmd, arg)
    endif
  endfor
  return [term_args, term_cmd]
endfun

fun! s:TermArgsToTermOpts(term_args, term_opts)
  for arg in map(copy(a:term_args), {idx, val -> split(val, '\s*=\s*')})
    if !s:IsShellArg(arg)
      continue
    endif
    let val = len(arg) > 1 ? arg[1] : v:true
    if arg[0] == "++close"
      let val = "close"
    elseif arg[0] == "++noclose"
      continue
    elseif arg[0] == "++open"
      let val = "open"
    endif
    
    let a:term_opts[s:TermArgMap(arg[0])] = val
  endfor
  return a:term_opts
endfun

fun! s:RunTerm(bang, term_winnr, term_opts, term_cmd)
    try
      let term_bufnr = term_start(a:term_cmd, a:term_opts)
    catch /.*/
      echohl ErrorMsg
      echomsg "vim-term cought: " . v:errmsg
      echohl Normal
      if &buftype != "terminal"
	return
      endif
    endtry
    if get(a:term_opts, "hidden", v:false)
      call setbufvar(term_bufnr, "term_rows", get(a:term_opts, "term_rows", 16))
      return
    endif
    let curwin = !a:term_winnr && get(a:term_opts, "curwin", v:false)
    if !curwin
      setl nonu nornu nospell wfh wfw
    endif
    if a:bang == "" && a:term_winnr != v:null
      exe a:term_winnr . "wincmd w"
    endif
    let b:term_rows = get(a:term_opts, "term_rows", 15)
    if !get(a:term_opts, "vertical", v:false) && !a:term_winnr && !curwin
      exe "resize" . b:term_rows
    endif
endfun

" Bang: also show shells
fun! s:Term(bang, vertical, args)
  let [term_args, term_cmd]   = s:SplitTermArgs(a:args)
  let [term_args, term_winnr] = s:TermWin(term_args)
  let term_opts = s:TermArgsToTermOpts(term_args, {"vertical": a:vertical, "term_rows": 16})
  if len(term_cmd)
    call s:RunTerm(a:bang, term_winnr, term_opts, term_cmd)
  else
    call s:ListTerms()
  endif
endfun

com! -bang -nargs=* -complete=file Term  :call s:Term(<q-bang>, v:false, s:ShellParse(<q-args>, <f-args>))
com! -bang -nargs=* -complete=file VTerm :call s:Term(<q-bang>, v:true,  s:ShellParse(<q-args>, <f-args>))

fun! s:NixTerm(bang, vertical, args)
  let nixfile = ""
  if !empty(a:args) && a:args[0] =~# '^\f\+\.nix$'
    let nixfile = a:args[0]
    call remove(a:args, 0)
  else
    let nixfile = ""
  endif

  " nix-shell options
  let nixattrs = []
  let idx = index(a:args, "-A")
  if idx >= 0
    call extend(nixattrs, ["-A", a:args[idx + 1]])
    call remove(a:args, idx, idx + 1)
  endif
  let idx = index(a:args, "--prune")
  if idx >= 0 
    call add(nixattrs, "--prune")
    call remove(a:args, idx)
  endif
  while index(a:args, "--arg") >= 0
    let idx = index(a:args, "--arg")
    call extend(nixattrs, ["--arg", a:args[idx+1], a:args[idx+2]])
    call remove(a:args, idx, idx + 2)
  endwhile
  while index(a:args, "--argstr") >= 0
    call extend(nixattrs, ["--argstr", a:args[idx+1], a:args[idx+2]])
    call remove(a:args, idx, idx + 2)
  endwhile

  let [term_args, term_cmd]   = s:SplitTermArgs(a:args)
  let [term_args, term_winnr] = s:TermWin(term_args)
  let term_opts = {"vertical": a:vertical, "term_rows": 16}
  if empty(term_cmd)
    let term_opts["term_finish"] = "close"
  endif
  let term_opts = s:TermArgsToTermOpts(term_args, term_opts)
  let nix_cmd = ["nix-shell"]
  if !empty(nixfile)
    call add(nix_cmd, nixfile)
  endif
  call extend(nix_cmd, nixattrs)
  if len(term_cmd)
    call add(nix_cmd, "--run")
    call extend(nix_cmd, term_cmd)
  endif
  call s:RunTerm(a:bang, term_winnr, term_opts, nix_cmd)
endfun

if exists("g:terminal_nix_term")
  com! -bang -nargs=* -complete=file NixTerm  :call s:NixTerm(<q-bang>, v:false, s:ShellParse(<q-args>, <f-args>))
  com! -bang -nargs=* -complete=file VNixTerm :call s:NixTerm(<q-bang>, v:true,  s:ShellParse(<q-args>, <f-args>))
endif
