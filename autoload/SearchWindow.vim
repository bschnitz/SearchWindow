" the core of the SearchWindow Plugin
"
" Last Change:	2015-05-31
" Maintainer:	  Benjamin Schnitzler <benjaminschnitzler@googlemail.com>
" License:	    This file is placed in the public domain.
" Dependencies:
" · Vim Plugin ToolBox (by Benjamin Schnitzler)
" · GNU grep and GNU find (contained in GNU findutils)
" · perl 5 interpreter
" · xargs supportting -0
" Comments:     
" · The code in this file shall be at most 80 characters in width
"
" Additional Comment:
" command chain is:
" find <addargs> -print0 | parse_find_cmd | \
"     xargs -0 grep -Hh <addargs> | format_grep > <resultsdir>/<resultsfile>
" if parse_find_cmd is '', it will be left out
" this command chain is configurable (see below)

if exists("g:loaded_SearchWindow")
  finish
endif
let g:loaded_SearchWindow = 1


"H Settings

let s:plugindir = fnamemodify(resolve(expand('<sfile>:p')), ':h')
let s:format_grep = fnamemodify(s:plugindir, ':h') . '/scripts/format_grep.pl'

" prototype for SearchWindow class objects
let s:swin = {}

" mandatory arguments for GNU find
let s:find_args = '-print0'

" optional arguments, which may be user defined
let s:swin.find_addargs = ''

" mandatory arguments for GNU grep
let s:grep_args = '-Hn'

" optional arguments, which may be user defined
let s:swin.grep_addargs = ''

" see comment about command chain above; this one is most qualified for 'sort'
let s:swin.parse_find_cmd = ''

" the filetype for the results file (argument for the format_grep command)
let s:swin.filetype = ''

" find command
let s:swin.find = 'find'

" grep command
let s:swin.grep = 'grep'

" file the results shall be written to
let s:swin.resultsfile = 'SearchWindowResults'

" diretory where the results file shall be stored
let s:swin.resultsdir = '.'

" xargs command
let s:xargs = 'xargs -0'

" modifiers for the split command issued when opening the search window
let s:splitmods = 'botright'


"H Implementation

" creates a new object of the SearchWindow class
func! SearchWindow#CreateNewInstance()
  let l:instance = copy(s:swin)
  return l:instance
endfunc

" reload the contents of the search window
"
" stay - optional (defaults to 1)
"        if 0, move the window focus to the search window
func! s:swin.ReloadSearchWindow(...)
  let l:stay = a:0 == 0 || a:1 == 1
  let l:mark = ToolBox#WindowMarkers#MarkWindow()
  call self.GoToSearchWindow()
  edit!
  if l:stay
    ToolBox#WindowMarkers#GoToWindowByMark(l:mark)
  endif
endfunc

" uses find and grep to search for <pattern>
"
" Arguments:
" pattern - the search pattern provided to grep
" open_search_window - (optional, default is 0)
"                      if 1, open the search window, if it isn't alreay open
" stay               - (optional, default is 1)
"                      if 0, go to the search window (if it is open)
func! s:swin.Search(pattern, ...)
  let l:open_search_window = a:0 > 0 && a:1 == 1
  let l:stay = a:0 > 1 && a:2 == 1

  let l:resfile = self.resultsdir . "/" . self.resultsfile
  let l:format_grep = s:format_grep . " " . self.filetype
  let l:find = self.find ." ". self.find_addargs ." ". s:find_args
  if self.parse_find_cmd != ""
    let l:find = l:find ." | ". self.parse_find_cmd
  endif
  let l:grep = self.grep ." ".s:grep_args." ". self.grep_addargs ." ". a:pattern
  let l:cmd = l:find." | xargs -0 ".l:grep." | ".l:format_grep." > ".l:resfile
  let self.resfile = l:resfile
  silent call system(l:cmd)

  if l:open_search_window
    call self.OpenSearchWindow(l:stay)
  endif

  call self.ReloadSearchWindow(l:stay)
endfunc

" tests if the search window for this instance of SearchWindow already exists
"
" Return Value:
" 1 if it exists, 0 otherwise
func! s:swin.SearchWindowIsOpen()
  if exists('self.result_window') && self.result_window !=# ""
    if ToolBox#WindowMarkers#MarkedWindowExists(self.result_window)
      return 1
    else
      let self.result_window = ""
    endif
  endif
  return 0
endfunc

" tests if the current window is the search window
"
" Return Value:
" 1 if the current window is the search window, 0 otherwise
func! s:swin.CurrentWindowIsSearchWindow()
  if ! self.SearchWindowIsOpen()
    return 0
  else
    return self.result_window ==# ToolBox#WindowMarkers#GetWindowMark() 
  endif
endfunc

" moves the window focus to the search window, if it exists
func! s:swin.GoToSearchWindow()
  if self.SearchWindowIsOpen()
    call ToolBox#WindowMarkers#GoToWindowByMark(self.result_window)
  endif
endfunc

" splits the window and opens the search window
"
" Argument:
" stay - (optional, defaults to 1)
"        if 1, stay in the seach window after opening it, else get back
"
" Return Value:
" the identifying mark of the search window
func! s:swin.OpenSearchWindow(...)
  let l:stay = a:0 == 0 || a:1 == 1

  if self.CurrentWindowIsSearchWindow()
    return self.result_window
  elseif self.SearchWindowIsOpen()
    if ! l:stay
      call ToolBox#WindowMarkers#GoToWindowByMark(self.result_window)
    endif
  else
    let self.active_window = ToolBox#WindowMarkers#MarkWindow()
    let l:resfile = self.resultsdir . "/" . self.resultsfile
    exec s:splitmods ." split ". l:resfile
    let self.resfile = l:resfile
    let self.result_window = ToolBox#WindowMarkers#MarkWindow()
    if exists("*self.OnOpenSearchWindow")
      call self.OnOpenSearchWindow()
    endif

    if l:stay
      call ToolBox#WindowMarkers#GoToWindowByMark(self.active_window)
    endif
  endif

  return self.result_window
endfunc

func! s:swin.TestLineStartsWithNumber(lnr)
  let l:words = split(getline(a:lnr), '\W\+')
  if len(l:words) > 0 && l:words[0] =~ "^[0-9]\\+$"
    return l:words[0]
  endif
  return ""
endfunc

" opens a search result from the search window
"
" Comment:
" opens the currently selected search result from the search window. this is the
" search result, the cursor is currently over. this is the search result, the
" cursor is currently over.
"
" Arguments:
" winnr - (optional, defaults to 0)
"         the number of the window to open the result in; if 0, use the window
"         which was active, when the search window was opened; if the specified
"         window doesn't exist, the behaviour of this function is undetermined!
"
" Todo:
" split this function into smaller parts
func! s:swin.OpenSearchResult()
  let l:tabnr = 0
  let l:winnr = a:0 > 0 ? a:1 : 0
  let l:destwin = [l:tabnr, l:winnr]
  if l:winnr == 0
    let l:destwin_mark = self.active_window
    let l:destwin = ToolBox#WindowMarkers#GetWindowNumberByMark(l:destwin_mark)
    if empty(l:destwin)
      echoerr "Window to open search result in does not found!"
      return
    endif
  endif

  " we should already be in the search window, just to make sure ...
  call self.GoToSearchWindow()

  " test if the cursor is positioned in a line with a result
  let l:curlnr = line('.')
  let l:dstlnr = TestLineStartsWithNumber(l:curlnr)
  if l:dstlnr == ""
    return
  endif

  " find the line containing the filename
  let l:curlnr = l:curlnr - 1
  while l:curlnr > 1 && TestLineStartsWithNumber(l:curlnr) != ""
    let l:curlnr = l:curlnr - 1
  endwhile

  " didnt find a line containing a filename (shouldn't have happend, but ...)
  if l:curlnr <= 1
    return
  endif

  " get the filename of the file the result is contained in
  let l:filename = getline(l:curlnr)[2:]

  " save the window number of the search window
  let l:winnr = winnr()

  " move to the destination tab and window
  if l:destwin[0] > 0
    exe "tabnext ".l:destwin[0]
  endif
  exe l:destwin[1] . "wincmd w"

  " open the result:
  exe "edit " . l:filename
  " position the cursor on the line containing the result
  call setpos(".", [0, l:dstlnr, 0, 0])
  " open all folds
  normal zR
  " highlight the line with the result:
  exe "match WildMenu /\\%".l:dstlnr."l/"
  " center the line the cursor is on (d.i. the line containing the result)
  normal zz

  " get back to the search window
  exe l:winnr . "wincmd w"
endfunc

"H vim: set tw=80 colorcolumn=+1 :
