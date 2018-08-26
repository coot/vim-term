if !exists("g:vim_term_termwin")
  let g:vim_term_termwin = v:false
endif

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

fun! s:FindTermWin()
  let tab = tabpagenr()
  for win in getwininfo()
    if win.terminal == 1 && win.tabnr == tab
      return win
    endif
  endfor
  return {}
endfun

fun! s:IsShellArg(arg)
  if index(['++close', '++nokill', '++noclose', '++open', '++curwin', '++hidden', '++rows', '++cols', '++eof', '++norestore', '++kill', '++cwd'], a:arg[0]) != -1
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

fun! s:LeftAlign(s, d)
  return a:s . repeat(' ', max([a:d - len(a:s), 0]))
endfun

" Returns a list of terminal buffers, if term_shell is false include only
" shells.
fun! s:TermBufs(term_shell)
  return filter(map(sort(term_list(), 'n'), {key, bufnr -> getbufinfo(bufnr)[0]}), {key, val -> getbufvar(val.bufnr, "term_shell") != a:term_shell})
endfun

" todo:
" - add # pointer: `ListTerms#` jumps to previous pointer position
"   (the <c-^> key could be remapped in term window)
fun! s:ListTerms(bang, count, term_bufs, jump_one, winnr, win, vertical, termwin)
  if len(a:term_bufs) == 0
    return
    if a:winnr
      wincmd p
    endif
  endif
  if a:jump_one && len(a:term_bufs) == 1
    let idx = 1
  elseif a:count >= 1 && a:count <= len(a:term_bufs)
    let idx = a:count
  else
    let n  = max(map(copy(a:term_bufs), {idx, buf -> len(join(job_info(term_getjob(buf.bufnr))['cmd'], ' '))}))
    let mt = 16 + n + max(map(copy(a:term_bufs), {idx, buf -> len(term_gettitle(buf.bufnr)) + 2}))
    if mt > &co
      let n = max([max(map(copy(a:term_bufs), {idx, buf -> len(bufname(buf.bufnr))})), 10])
    endif
    echohl Title
    echo printf("%s %s %s %s %s", "idx", "bufnr", "st", s:LeftAlign("cmd", n), "title")
    echohl Normal
    let idx = inputlist(map(copy(a:term_bufs), {idx, buf -> printf(
	  \ "%2d  [%3d] %s %s %s",
	  \ idx + 1,
	  \ buf.bufnr,
	  \ s:LeftAlign(join(map(split(term_getstatus(buf.bufnr), ","), {idx, st -> st[0]}), ""), 2),
	  \ (mt <= &co)
	    \  ? s:LeftAlign(join(job_info(term_getjob(buf.bufnr))["cmd"], " "), n)
	    \  : s:LeftAlign(bufname(buf.bufnr)[1:], n),
	  \ !empty(term_gettitle(buf.bufnr)) ? "[" . term_gettitle(buf.bufnr) . "]" : ""
	  \ )}))
  endif
  if idx == 0 || idx > len(a:term_bufs)
    if a:winnr
      wincmd p
    endif
    return
  endif
  let term = a:term_bufs[idx-1]
  if a:termwin && !empty(a:win)
    exe a:win.winnr . "wincmd w"
    exe "b " . term.bufnr
    setl buftype=terminal
  else
    exe (a:vertical ? "vertical" : "") . " sb ". term.bufnr
    setl buftype=terminal
    setl nonu nornu nospell wfh wfw
    if !exists("b:term_rows")
      let b:term_rows = 16
    endif
    if !a:vertical && b:term_rows != v:null
      exe "resize" . b:term_rows
    endif
  endif
  if empty(a:bang) && (empty(a:win) || a:winnr != get(a:win, "winnr"))
    " jump back
    wincmd p
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
  elseif a:name == "++nokill"
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
  let winnr = v:null
  let win   = {}
  if index(a:term_args, "++termwin") >= 0
    call filter(a:term_args, {key, arg -> split(arg, '\s*=\s*')[0] != "++termwin"})
    let winnr      = v:null
    let win        = s:FindTermWin()
    if !empty(win)
      if win.winnr != winnr
	let winnr = winnr()
	call add(a:term_args, "++curwin")
	exe win.winnr . "wincmd w"
      endif
    endif
  endif
  let idx = index(a:term_args, "++nokill")
  if idx == -1
    call add(a:term_args, "++kill=kill")
  else
    call remove(a:term_args, idx)
  endif
  return [winnr, win]
endfun

" Split terminal arguments from the command arguments.
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

" Map term args to terminal options, second argument is the set of default
" terminal options.
fun! s:TermArgsToTermOpts(term_args, term_opts, term_win)
  if !get(a:term_opts, "vertical", v:false) && !a:term_win
    let a:term_opts["term_rows"] = get(a:term_opts, "term_rows", 16)
  endif
  for arg in map(copy(a:term_args), {idx, val -> split(val, '\s*=\s*')})
    if !s:IsShellArg(arg)
      continue
    endif
    let val = len(arg) > 1 ? arg[1] : v:true
    if arg[0] == "++close"
      let val = "close"
    elseif arg[0] == "++noclose"
      if get(a:term_opts, "term_finish", v:null) == "close"
	call remove(a:term_opts, "term_finish")
      endif
      continue
    elseif arg[0] == "++open"
      let val = "open"
    elseif arg[0] == "++nokill"
      let val = "term"
    elseif arg[0] == "++cwd"
      let val = expand(arg[1])
    endif
    
    let a:term_opts[s:TermArgMap(arg[0])] = val
  endfor
  return a:term_opts
endfun

" Low level wrapper around `:terminal` command.
" a:bang       - if not set jump back to the original window
" a:term_shell - v:true if we run a shell
" a:winnr      - non v:null iff we jumped to termwin (in s:TermWin)
" a:term_opts  - terminal optsion
" a:term_cmd   - terminal command
fun! s:Terminal(bang, term_shell, winnr, term_opts, term_cmd)
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
  if exists("term_bufnr")
    call setbufvar(term_bufnr, "term_shell", a:term_shell)
  endif
  if get(a:term_opts, "hidden", v:false)
    call setbufvar(term_bufnr, "term_rows", get(a:term_opts, "term_rows", 16))
    return
  endif
  let curwin = !a:winnr && get(a:term_opts, "curwin", v:false)
  if !curwin
    setl nonu nornu nospell wfh wfw
    let b:term_rows = get(a:term_opts, "term_rows", 16)
    if !get(a:term_opts, "vertical", v:false) && !a:winnr
      exe "resize" . b:term_rows
    endif
  endif
  if empty(a:bang) && a:winnr != winnr()
    " jump back
    wincmd p
  endif
endfun

" Run a shell.
fun! s:Shell(bang, count, vertical, args)
  let term_bufs = s:TermBufs(v:false)
  let args      = split(a:args)
  if exists("g:vim_term_termwin") && g:vim_term_termwin
    if empty(filter(copy(args), {idx, arg -> index(["++notermwin", "++termwin", "++hidden"], arg) >= 0}))
      call add(args, "++termwin")
    endif
  endif
  if a:bang == "!" || empty(term_bufs)
    let term_opts    = {"vertical": a:vertical, "term_kill": "kill", "term_finish": "close"}
    let term_args    = s:SplitTermArgs(args)[0]
    let [winnr, win] = s:TermWin(term_args)
    let term_opts    = s:TermArgsToTermOpts(term_args, term_opts, !empty(winnr))
    return s:Terminal("!", v:true, winnr, term_opts, s:ShellParse(&shell, split(&shell)))
  else
    let win = s:FindTermWin()
    call s:ListTerms("!", a:count, term_bufs, v:true, v:null, win, a:vertical, index(args, "++termwin") != -1)
  endif
endfun

com! -bang -count=0 -nargs=* Shell  call s:Shell(<q-bang>, <count>, v:false, <q-args>)
com! -bang -count=0 -nargs=* VShell call s:Shell(<q-bang>, <count>, v:true,  <q-args>)

" Run a command in a termianl.
fun! s:Term(bang, count, vertical, args)
  let [term_args, term_cmd] = s:SplitTermArgs(a:args)
  if exists("g:vim_term_termwin") && g:vim_term_termwin
    if empty(filter(copy(term_args), {idx, arg -> index(["++notermwin", "++termwin", "++hidden"], arg) >= 0}))
      call add(term_args, "++termwin")
    endif
  endif
  let [winnr, win] = s:TermWin(term_args)
  let term_opts	   = s:TermArgsToTermOpts(term_args, {"vertical": a:vertical}, !empty(winnr))
  let list_terms   = index(term_cmd, "++ls") >= 0
  if len(term_cmd) && !list_terms
    call s:Terminal(a:bang, v:false, winnr, term_opts, term_cmd)
  else
    if list_terms
      call s:ListTerms(a:bang, a:count, extend(s:TermBufs(v:false), s:TermBufs(v:true)), v:false, winnr, win, a:vertical, !empty(winnr))
    else
      call s:ListTerms(a:bang, a:count, s:TermBufs(v:true), v:true, winnr, win, a:vertical, !empty(winnr))
    endif
  endif
endfun

com! -bang -nargs=* -complete=file Term  :call s:Term(<q-bang>, <count>, v:false, s:ShellParse(<q-args>, <f-args>))
com! -bang -nargs=* -complete=file VTerm :call s:Term(<q-bang>, <count>, v:true,  s:ShellParse(<q-args>, <f-args>))

fun! s:NixArgs(args)
  let nixfile = ""
  if !empty(a:args) && a:args[0] =~# '^\f\+\.nix$'
    let nixfile = a:args[0]
    call remove(a:args, 0)
  else
    let nixfile = ""
  endif

  let len = len(a:args)

  " nix-shell options
  let nix_args = []
  let idx = 0
  let remove   = []
  let break    = v:false
  while idx < len
    let arg = a:args[idx]
    if arg == "-A"
      if len >= idx + 2
	call extend(nix_args, ["-A", a:args[idx + 1]])
	call extend(remove, [idx, idx + 1])
	let idx += 2
	continue
      else
	call extend(nix_args, ["-A"])
	call extend(remove, [idx])
	break
      endif
    elseif arg == "--pure"
      call add(nix_args, "--pure")
      call add(remove, idx)
      let idx += 1
      continue
    elseif arg == "--arg"
      if len >= idx + 3
	call extend(nix_args, ["--arg", a:args[idx+1], a:args[idx+2]])
	call extend(remove, [idx, idx + 1, idx + 2])
	let idx += 3
	continue
      elseif len >= idx + 2
	call extend(nix_args, ["--arg", a:args[idx+1]])
	call extend(remove, [idx, idx + 1])
	let idx += 2
	break
      else
	call extend(nix_args, ["--arg"])
	call extend(remove, [idx])
	let idx += 1
	break
      endif
    elseif arg == "--argstr"
      if len >= idx + 3
	call extend(nix_args, ["--argstr", a:args[idx+1], a:args[idx+2]])
	call extend(remove, [idx, idx + 1, idx + 2])
	let idx += 3
	continue
      elseif len >= idx + 2
	call extend(nix_args, ["--argstr", a:args[idx+1]])
	call extend(remove, [idx, idx + 1])
	let idx += 2
	break
      elseif len >= idx + 1
	call extend(nix_args, ["--argstr"])
	call extend(remove, [idx])
	let idx += 1
	break
      endif
    endif
    let idx += 1
  endwhile

  for idx in reverse(remove)
    call remove(a:args, idx)
  endfor

  let nixfile = expand(nixfile)
  if !filereadable(nixfile)
    let nixfile = ""
  endif
  return [nixfile, nix_args]
endfun

" Open a nix-shell or a run a command in a nix shell
" TODO: list nix terminals
fun! s:NixTerm(bang, vertical, args)
  let cterm_win		    = &buftype == "terminal"
  let [term_args, term_cmd] = s:SplitTermArgs(a:args)
  let [nixfile,   nix_args] = s:NixArgs(term_cmd)
  let [winnr, win]          = s:TermWin(term_args)
  let term_opts		    = {"vertical": a:vertical}
  if empty(term_cmd)
    let term_opts["term_finish"] = "close"
  endif
  let term_opts = s:TermArgsToTermOpts(term_args, term_opts, !empty(winnr))
  let nix_cmd = ["nix-shell"]
  if !empty(nixfile)
    call add(nix_cmd, nixfile)
  endif
  call extend(nix_cmd, nix_args)
  if len(term_cmd)
    if index(term_cmd, "--run") == -1 && index(term_cmd, "--command") == -1
      call add(nix_cmd, "--run")
    endif
    call extend(nix_cmd, term_cmd)
  endif
  let term_bang = !empty(term_cmd) ? "" : "!"
  call s:Terminal(term_bang, empty(term_cmd), winnr, term_opts, nix_cmd)
endfun

if exists("g:vim_term_nixterm")
  com! -bang -nargs=* -complete=file NixTerm  :call s:NixTerm(<q-bang>, v:false, s:ShellParse(<q-args>, <f-args>))
  com! -bang -nargs=* -complete=file VNixTerm :call s:NixTerm(<q-bang>, v:true,  s:ShellParse(<q-args>, <f-args>))
endif
