" the core of the SearchWindow Plugin
"
" Last Change:	2015-05-31
" Maintainer:	  Benjamin Schnitzler <benjaminschnitzler@googlemail.com>
" License:	    This file is placed in the public domain.
" Dependencies:
" · Vim Plugin ToolBox (by Benjamin Schnitzler)
" · GNU grep and GNU find (contained in GNU findutils)
" · xargs supportting -0
" Comments:     
" · The search window is the window containing the list of all matches
" · The result window is the window which holds a buffer for a file in which one
"   or more matches were located
" · The Commands for finding files and searching in them can be configured, so
"   the dependencies only apply to the unconfigured command chain.
"
" Additional Comment:
" · The code in this file shall be at most 80 characters in width

if exists("g:loaded_SearchWindow")
  finish
endif
let g:loaded_SearchWindow = 1


"H Settings

" this function loads the default configuration of the search window
func! SearchWindow#Configure() dict
  " path to the file where the results shall be written to
  let self.resultsfile = 'SearchWindowResults'

  " root of the search
  let self.searchpath = '.'

  " modifiers for the split command issued when opening the search window
  let self.splitmods = 'botright'

  " the command, which is used to collect the results; can be configured
  let self.cmd = 
    \'find %(findargs) %(searchpath) %(findexpression) -print0 | sort |'.
    \'xargs -0 grep -Hn %(grepargs) %(pattern) > %(resultsfile)'

  let self.arguments = {
  \  '%(findargs)'       : '',
  \  '%(searchpath)'     : self.searchpath,
  \  '%(findexpression)' : '',
  \  '%(grepargs)'       : '',
  \  '%(resultsfile)'    : self.resultsfile,
  \  '%(pattern)'        : ''
  \}

  " highlighting for the line containing the match result window
  let self.hi_group_matchline = 'WildMenu'

  " highlighting for the match (search window and result window)
  let self.hi_group_match = 'Search'

  " default mapping for opening a file containing a result in the result window
  let self.map_open_result = '<space>'

  " filetype of the window containing the matches
  let self.filetype = ''

  " this function is executed after the buffer of the results window was loaded
  let self.OnLoadResultsWindowBuffer =
        \function('SearchWindow#OnLoadResultsWindowBuffer')

  " this function is executed directly after the search window was loaded
  let self.OnLoadSearchWindowBuffer =
        \function('SearchWindow#OnLoadSearchWindowBuffer')

  " for each line in the search wind., which contains a result, this is executed
  " let self.FormatOutputLine = \function('SearchWindow#FormatCppOutputLine')
endfunc

"H Implementation

" creates a new object of the SearchWindow class
"
" Usage:
" let swin = SearchWindow#CreateNewInstance()
func! SearchWindow#CreateNewInstance()
  let l:swin = {
        \ 'SetResultsFile'     : function('SearchWindow#SetResultsFile'),
        \ 'SetSearchPath'      : function('SearchWindow#SetSearchPath'),
        \ 'ReloadSearchWindow' : function('SearchWindow#ReloadSearchWindow'),
        \ 'Search'             : function('SearchWindow#Search'),
        \ 'FormatGrepOutput'   : function('SearchWindow#FormatGrepOutput'),
        \ 'SearchWindowIsOpen' : function('SearchWindow#SearchWindowIsOpen'),
        \ 'CurrentWindowIsSearchWindow' :
                \ function('SearchWindow#CurrentWindowIsSearchWindow'),
        \ 'GoToSearchWindow'   : function('SearchWindow#GoToSearchWindow'),
        \ 'OpenSearchWindow'   : function('SearchWindow#OpenSearchWindow'),
        \ 'GoToSearchResult'   : function('SearchWindow#GoToSearchResult'),
        \ 'GetResultInfo'      : function('SearchWindow#GetResultInfo'),
        \ 'OpenSearchResult'   : function('SearchWindow#OpenSearchResult'),
        \ 'Configure'          : function('SearchWindow#Configure'),
  \}
  call l:swin.Configure()
  return l:swin
endfunc

" closes unclosed c comments ('/*') and '#if 0' statements
"
" Comment:
" this is useful if you want to enable syntax highlighting in the results file,
" since lines with unclosed comments or #if 0 would break the highlighting until
" they are closed on another line.
"
" Usage:
" enable this functionality with:
" let swin.FormatOutputLine = function("SearchWindow#FormatCppOutputLine")
func! SearchWindow#FormatCppOutputLine(line)
  " nicht geschlossene mehrzeilige Kommentare (/* ...) schließen
  let l:pattern = '\(\/\*\(\(\*\/\)\@!.\)*\)$'
  let l:line = substitute(a:line, l:pattern, '\1 *** closed comment */', '')

  " #if 0 abschließen
  let l:line = substitute(l:line,'\(#if\s*0.*\)$' , '\1 #', '')

  return l:line
endfunc

" this function is executed directly after the search window was loaded
"
" Comment:
" to have the actual matches highlighted, self.pattern must be set to the search
" pattern provided to the grep command
func SearchWindow#OnLoadSearchWindowBuffer() dict
  let l:mapping = self.map_open_result . ' :call OpenProjectSearchResult()<cr>'
  exe 'nnoremap <buffer> ' . l:mapping
  normal zR
  setlocal nomodifiable
  let &ft = self.filetype
  if exists('self.matchid') | call matchdelete(self.matchid) | endif
  if exists('self.pattern') && self.hi_group_match != ""
    let self.matchid = matchadd(self.hi_group_match, '\c'.self.pattern)
  endif
endfunc

" this function is executed after the buffer of the results window was loaded
"
" Comment:
" to have the actual matches highlighted, self.pattern must be set to the search
" pattern provided to the grep command
func SearchWindow#OnLoadResultsWindowBuffer(lnr) dict
  call clearmatches()

  if self.hi_group_matchline != ""
    call matchadd(self.hi_group_matchline, '\%'.a:lnr.'l\S.*\S\s*')
  endif

  if exists('self.pattern') && self.hi_group_match != ""
    call matchadd(self.hi_group_match, '\c'.self.pattern)
  endif
endfunc

" set the path of the file the results will be written to
"
" Comment:
" sets self.resultsfile and self.arguments['%(resultsfile)']
func! SearchWindow#SetResultsFile( file ) dict
  let self.resultsfile = a:file
  let self.arguments['%(resultsfile)'] = a:file
endfunc

" set the directory under which will be searched
"
" Comment:
" sets self.searchpath and self.arguments['%(searchpath)']
func! SearchWindow#SetSearchPath( path ) dict
  let self.searchpath = a:path
  let self.arguments['%(searchpath)'] = a:path
endfunc

" reload the contents of the search window
"
" stay - optional (defaults to 1)
"        if 0, move the window focus to the search window
func! SearchWindow#ReloadSearchWindow(...) dict
  let l:stay = a:0 == 0 || a:1 == 1
  if ! self.CurrentWindowIsSearchWindow()
    let self.active_window = ToolBox#WindowMarkers#MarkWindow()
    if self.GoToSearchWindow() == 0 | return | endif
  else
    let l:stay = 0
  endif
  edit!
  if exists("*self.OnLoadSearchWindowBuffer")
    call self.OnLoadSearchWindowBuffer()
  endif
  if l:stay
    call ToolBox#WindowMarkers#GoToWindowByMark(self.active_window)
  endif
endfunc

" uses self.cmd to find what is specified by <arguments>
"
" Arguments:
" arguments - a dictionary which is used to replace the placeholders in
"             self.cmd; replacements not provided by <arguments> will be
"             replaced using self.arguments.
" stay     - (optional defaults to 1)
"            if 0, move to search window, otherwise stay in current window
" open_search_window
"          - (optional, default is 0)
"            if not 0, open the search window, if it isn't alreay open
func! SearchWindow#Search(arguments, ...) dict
  let l:arguments = a:arguments
  call extend( l:arguments, self.arguments, "keep" )
  let l:stay = a:0 > 0 ? a:1 : 1
  let l:open_search_window = a:0 > 1 ? a:2 : 0
  let l:cmd = ToolBox#SubstituteFromDictionary(self.cmd, l:arguments)
  silent call system(l:cmd)
  call self.FormatGrepOutput(self.resultsfile)
  if l:open_search_window != 0
    call self.OpenSearchWindow()
  endif
  call self.ReloadSearchWindow(l:stay)
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
func! SearchWindow#FormatGrepOutput(file) dict
  let l:lines = readfile(a:file)
  let l:lines_out = []

  call add(l:lines_out, len(l:lines) . " results")

  let l:file = ""
  for l:line in l:lines
    let l:split = matchlist( l:line, '^\(.\{-}\):\(.\{-}\):\(.\{-}\)$' )
    let [ l:all, l:filenew, l:linenr, l:match; l:rest ] = l:split
    if l:file !=# l:filenew
      let l:fileabs = ToolBox#GetAbsPath(self.searchpath, l:filenew)
      let l:fileabs = resolve(expand(l:fileabs))
      call add(l:lines_out, "")
      call add(l:lines_out, l:fileabs)
      let l:file = l:filenew
    endif
    if exists("*self.FormatOutputLine")
      let l:match = self.FormatOutputLine(l:match)
    endif
    call add( l:lines_out, printf("%4d  ", l:linenr).l:match )
  endfor

  call writefile(l:lines_out, a:file)
endfunc

" tests if the search window for this instance of SearchWindow already exists
"
" Return Value:
" 1 if it exists, 0 otherwise
func! SearchWindow#SearchWindowIsOpen() dict
  if exists('self.result_window') && self.result_window !=# ""
    if ToolBox#WindowMarkers#MarkedWindowExists(self.result_window)
      return 1
    else
      call confirm( self.result_window )
      call confirm( ToolBox#WindowMarkers#MarkedWindowExists(self.result_window) )
      let self.result_window = ""
    endif
  endif
  return 0
endfunc

" tests if the current window is the search window
"
" Return Value:
" 1 if the current window is the search window, 0 otherwise
func! SearchWindow#CurrentWindowIsSearchWindow() dict
  if ! self.SearchWindowIsOpen()
    return 0
  else
    return self.result_window ==# ToolBox#WindowMarkers#GetWindowMark() 
  endif
endfunc

" moves the window focus to the search window, if it exists
"
" Return Value:
" 1, if successful, 0 else
func! SearchWindow#GoToSearchWindow() dict
  if self.SearchWindowIsOpen()
    let l:ok = ToolBox#WindowMarkers#GoToWindowByMark(self.result_window)
    return len(l:ok) > 0 ? 1 : 0
  endif
  return 0
endfunc

" splits the window and opens the search window
"
" Argument:
" stay - (optional, defaults to 1)
"        if 1, stay in the seach window after opening it, else get back
"
" Return Value:
" the identifying mark of the search window
func! SearchWindow#OpenSearchWindow(...) dict
  let l:stay = a:0 == 0 || a:1 == 1

  if self.CurrentWindowIsSearchWindow()
    return self.result_window
  elseif self.SearchWindowIsOpen()
    if ! l:stay
      call ToolBox#WindowMarkers#GoToWindowByMark(self.result_window)
    endif
  else
    let self.active_window = ToolBox#WindowMarkers#MarkWindow()
    let l:resfile = self.resultsfile
    exec self.splitmods ." split ". l:resfile
    let self.result_window = ToolBox#WindowMarkers#MarkWindow()
    if exists("*self.OnLoadSearchWindowBuffer")
      call self.OnLoadSearchWindowBuffer()
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
func! SearchWindow#GoToSearchResult( filepath, lnr ) dict
  " open the result:
  exe "edit " . a:filepath

  if exists("*self.OnLoadResultsWindowBuffer")
    call self.OnLoadResultsWindowBuffer(a:lnr)
  endif

  " position the cursor on the line containing the result
  call setpos(".", [0, a:lnr, 0, 0])

  " open all folds
  normal zR

  " highlight the line with the result:
  " exe 'match WildMenu /\%'.a:lnr.'l\S.*\S\s*/'

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
func! SearchWindow#GetResultInfo() dict
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
func! SearchWindow#OpenSearchResult() dict
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
