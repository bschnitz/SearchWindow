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
"     xargs -0 grep -Hn <addargs> | format_grep > <resultsdir>/<resultsfile>
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

" diretory where the results file shall be stored
let s:swin.resultsdir = '.'

" file the results shall be written to
let s:swin.resultsfile = 'SearchWindowResults'

" xargs command
let s:xargs = 'xargs -0'

" modifiers for the split command issued when opening the search window
let s:splitmods = 'botright'

let s:swin.cmd = 
      \'find %(findargs) %(searchpath) %(findexpression) -print0 | '.
      \'xargs -0 grep -Han %(grepargs) %(pattern) > '.
      \'%(resultsdir)/%(resultsfile)'

let s:swin.arguments = {
\  '%(findargs)'       : '',
\  '%(searchpath)'     : '',
\  '%(findexpression)' : '-regex ''\(.*\.cc\|.*\.cpp\|.*\.h\|.*\.hpp\)$''',
\  '%(grepargs)'       : '',
\  '%(resultsdir)'     : s:swin.resultsdir,
\  '%(resultsfile)'    : s:swin.resultsfile,
\  '%(pattern)'        : '''#if 0'''
\}

"H Implementation

" creates a new object of the SearchWindow class
func! SearchWindow#CreateNewInstance()
  let l:instance = copy(s:swin)
  return l:instance
endfunc

" set the directory where the file with the results is stored
"
" Comment:
" sets self.resultsdir and self.arguments['%(resultsdir)']
func! s:swin.SetResultsDir( dir )
  let self.resultsdir = a:dir
  let self.arguments['%(resultsdir)'] = a:dir
endfunc

" set the name of the file the results will be written to
"
" Comment:
" sets self.resultsfile and self.arguments['%(resultsfile)']
func! s:swin.SetResultsFile( file )
  let self.resultsfile = a:file
  let self.arguments['%(resultsfile)'] = a:file
endfunc

" reload the contents of the search window
"
" stay - optional (defaults to 1)
"        if 0, move the window focus to the search window
func! s:swin.ReloadSearchWindow(...)
  let l:stay = a:0 == 0 || a:1 == 1
  let self.active_window = ToolBox#WindowMarkers#MarkWindow()
  call self.GoToSearchWindow()
  edit!
  if l:stay
    ToolBox#WindowMarkers#GoToWindowByMark(self.active_window)
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

" uses self.cmd to find what is specified by <arguments>
"
" Arguments:
" argument - a dictionary which is used to replace the placeholders in self.cmd
" stay     - if 0, move to search window, otherwise stay in current window
" pattern - the search pattern provided to grep
" open_search_window - (optional, default is 0)
"                      if 1, open the search window, if it isn't alreay open
" stay               - (optional, default is 1)
"                      if 0, go to the search window (if it is open)
func! s:swin.SearchII(arguments, ...)
  let l:stay = a:0 > 0 ? a:1 : 1
  let l:cmd = ToolBox#SubstituteFromDictionary(self.cmd, self.arguments)
  silent call system(l:cmd)
  call self.FormatGrepOutput(self.resultsdir . "/" . self.resultsfile)
  call self.OpenSearchWindow()
  call self.ReloadSearchWindow(l:stay)
endfunc

func! s:swin.FormatOutputLine(line)
  " nicht geschlossene mehrzeilige Kommentare (/* ...) schließen
  let l:pattern = '\(\/\*\(\(\*\/\)\@!.\)*\)$'
  let l:line = substitute(a:line, l:pattern, '\1 *** closed comment */', '')

  " #if 0 abschließen
  let l:line = substitute(l:line,'\(#if\s*0.*\)$' , '\1 #', '')

  return l:line
endfunc

" formats the output of the grep command for the search window
"
" Argument:
" file - the file where the output of the grep command was stored to, this is
"        also the file, where the formatted output will be written back to
"
" Comment:
" · expects the lines of the file to follow the following pattern:
"   <linenr>:<filepath>:<match>
" · the output will follow the following pattern (beginning with the first line
"   of the file, which is a special line showing the absolute number of matches)
"   <number> results
"
"   <filepath>
"   <linenr>  <match1 for filepath>
"   <linenr>  <match2 for filepath>
"   ...
func! s:swin.FormatGrepOutput(file)
  let l:lines = readfile(a:file)
  let l:lines_out = []

  call add(l:lines_out, len(l:lines) . " results")

  let l:file = ""
  for l:line in l:lines
    let l:split = matchlist( l:line, '^\(.\{-}\):\(.\{-}\):\(.\{-}\)$' )
    let [ l:all, l:filenew, l:linenr, l:match; l:rest ] = l:split
    if l:file !=# l:filenew
      let l:fileabs = resolve(expand(getcwd()."/".l:filenew))
      call add(l:lines_out, "")
      call add(l:lines_out, l:fileabs)
      let l:file = l:filenew
    endif
    let l:match = self.FormatOutputLine(l:match)
    call add( l:lines_out, printf("%4d  ", l:linenr).l:match )
  endfor

  call writefile(l:lines_out, a:file)
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

" opens, centers and highlights a search result in the current window
"
" Arguments:
" l:filepath - the file containing the result
" l:lnr      - the line in the file containing the result
"
" Additional Comment:
" opens all folds to ensure, that the result is visible immediately
func! s:swin.GoToSearchResult( filepath, lnr )
  " open the result:
  exe "edit " . a:filepath

  " position the cursor on the line containing the result
  call setpos(".", [0, a:lnr, 0, 0])

  " open all folds
  normal zR

  " highlight the line with the result:
  exe 'match WildMenu /\%'.a:lnr.'l\S.*\S\s*/'

  " center the line the cursor is on (d.i. the line containing the result)
  normal zz
endfunc

" analyzes a result in the search window and returns its location
"
" Comment:
" analyzes the current line in the current buffer, so the current buffer should
" be the search window for this function to work as expected.
"
" Return Value:
" a list of the form [ l:filename, l:lnr ], where l:filename is the file
" containing the result and l:lnr the line with the result in that file; if the
" current line does not contain a search result, returns ['', 0]
func! s:swin.GetResultInfo()
  " find the line containing the file name (this must not start with a number)
  let l:linenr = ToolBox#FindLineBackwards( '^\(\s*\d\)\@!\S' )

  " return, if no such line was found (d.i. current line contains no result)
  if l:linenr == 0 || l:linenr == line('.') | return ['', 0] | endif

  " get the filepath
  let l:filepath = getline(l:linenr)

  " get the number of the line containing the match (in the destination file)
  let l:dstlnr = str2nr(matchstr(getline('.'), '^\s*[0-9]\+\s' ))
  if l:dstlnr == "" | return ['', 0] | endif

  return [l:filepath, l:dstlnr]
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
" tabnr - (optional, defaults to 0)
"         the number of the tab containing the window to open the result in;
"         if 0, use the current tab (if winnr is 0, this has no effekt)
func! s:swin.OpenSearchResult()
  let l:tabnr = a:0 > 1 ? a:2 : 0
  let l:winnr = a:0 > 0 ? a:1 : 0
  let l:destwin = [l:tabnr, l:winnr]
  if l:winnr == 0
    let l:destwin_mark = self.active_window
    let l:destwin = ToolBox#WindowMarkers#GetWindowNumberByMark(l:destwin_mark)
    if empty(l:destwin)
      echoerr "Window to open search result in not found!"
      return
    endif
  endif

  " we should already be in the search window, just to make sure ...
  call self.GoToSearchWindow()

  " save the window number of the search window
  let l:winnr = winnr()

  " get the location of the result
  let [l:filepath, l:dstlnr] = self.GetResultInfo()
  if l:dstlnr == 0 | return | endif

  " move to the destination tab and window
  call ToolBox#GoToTabAndWin( l:destwin[0], l:destwin[1] )

  " open the file containing the result and center the result inside the window
  call self.GoToSearchResult( l:filepath, l:dstlnr )

  " get back to the search window
  exe l:winnr . "wincmd w"
endfunc

"H vim: set tw=80 colorcolumn=+1 :
