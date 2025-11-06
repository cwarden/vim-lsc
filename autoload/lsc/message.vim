if !exists('s:messages')
  " Store all server messages
  " Each entry: {message: string, level: string, time: string}
  let s:messages = []
endif

function! lsc#message#show(message, ...) abort
  call s:Echo('echo', a:message, get(a:, 1, 'Log'))
endfunction

function! lsc#message#showRequest(message, actions) abort
  let l:options = [a:message]
  for l:index in range(len(a:actions))
    let l:title = get(a:actions, l:index)['title']
    call add(l:options, (l:index + 1) . ' - ' . l:title)
  endfor
  let l:result = inputlist(l:options)
  if l:result <= 0 || l:result - 1 > len(a:actions)
    return v:null
  else
    return get(a:actions, l:result - 1)
  endif
endfunction

function! lsc#message#log(message, type) abort
  call s:Echo('echom', a:message, a:type)
endfunction

function! lsc#message#error(message) abort
  call s:Echo('echom', a:message, 'Error')
endfunction

function! s:Echo(echo_cmd, message, level) abort
  let [l:level, l:hl_group] = s:Level(a:level)
  exec 'echohl '.l:hl_group
  exec a:echo_cmd.' "[lsc:'.l:level.'] ".a:message'
  echohl None
  " Capture message for later retrieval
  call add(s:messages, {
      \ 'message': a:message,
      \ 'level': l:level,
      \ 'time': strftime('%Y-%m-%d %H:%M:%S')
      \})
  " Keep only the last 1000 messages
  if len(s:messages) > 1000
    let s:messages = s:messages[-1000:]
  endif
  " Auto-update quickfix if it's showing our messages
  if exists('s:quickfix_debounce')
    call timer_stop(s:quickfix_debounce)
  endif
  let s:quickfix_debounce = timer_start(100, funcref('<SID>UpdateQuickFix'))
endfunction

function! s:Level(level) abort
  if type(a:level) == type(0)
    if a:level == 1
      return ['Error', 'lscDiagnosticError']
    elseif a:level == 2
      return ['Warning', 'lscDiagnosticWarning']
    elseif a:level == 3
      return ['Info', 'lscDiagnosticInfo']
    endif
    return ['Log', 'None'] " Level 4 or unmatched
  endif
  if a:level ==# 'Error'
    return ['Error', 'lscDiagnosticError']
  elseif a:level ==# 'Warning'
    return ['Warning', 'lscDiagnosticWarning']
  elseif a:level ==# 'Info'
    return ['Info', 'lscDiagnosticInfo']
  endif
  return ['Log', 'None'] " 'Log' or unmatched
endfunction

" Show all captured server messages in the quickfix window
function! lsc#message#showInQuickFix() abort
  call setqflist([], ' ', {
      \ 'items': s:BuildQuickFixItems(),
      \ 'title': 'LSC Server Messages',
      \ 'context': {'client': 'LSC-Messages'}
      \})
  copen
endfunction

" Build quickfix items from stored messages
function! s:BuildQuickFixItems() abort
  let l:items = []
  for l:msg in s:messages
    let l:type = s:LevelToType(l:msg.level)
    call add(l:items, {
        \ 'text': '[' . l:msg.time . '] [' . l:msg.level . '] ' . l:msg.message,
        \ 'type': l:type
        \})
  endfor
  return l:items
endfunction

" Auto-update quickfix window if it's showing our messages
function! s:UpdateQuickFix(...) abort
  unlet s:quickfix_debounce
  let l:current = getqflist({'context': 1, 'idx': 1})
  let l:context = get(l:current, 'context', 0)
  if type(l:context) != type({}) ||
      \ !has_key(l:context, 'client') ||
      \ l:context.client !=# 'LSC-Messages'
    return
  endif
  " Update the quickfix list with new messages
  call setqflist([], 'r', {'items': s:BuildQuickFixItems()})
endfunction

" Convert level string to quickfix type
function! s:LevelToType(level) abort
  if a:level ==# 'Error'
    return 'E'
  elseif a:level ==# 'Warning'
    return 'W'
  elseif a:level ==# 'Info'
    return 'I'
  else
    return 'I'
  endif
endfunction

" Clear all stored messages
function! lsc#message#clear() abort
  let s:messages = []
endfunction

" Get count of stored messages
function! lsc#message#count() abort
  return len(s:messages)
endfunction
