" SearchWindow - a plugin for vim for searching a pattern in files
" Copyright (C) 2015 Benjamin Schnitzler
"
" This program is free software; you can redistribute it and/or modify it under
" the terms of the GNU General Public License as published by the Free Software
" Foundation; either version 3 of the License, or (at your option) any later
" version.
"
" This program is distributed in the hope that it will be useful, but WITHOUT
" ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
" FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License along with
" this program; if not, see <http://www.gnu.org/licenses/>.
"
" Description:  This is the core of the SearchWindow Plugin
" Last Change:	2015-05-31
" Maintainer:	  Benjamin Schnitzler <benjaminschnitzler@googlemail.com>
" License:	    GNU General Public License version 3
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

if exists("g:loaded_SearchWindow") || version < 700
  finish
endif
let g:loaded_SearchWindow = 1


"H Settings

" this function loads the default configuration of the search window
func! SearchWindow#Configure() dict
  " modifiers for the split command issued when opening the search window
  let self.splitmods = 'botright'

  " the command, which is used to collect the results; can be configured
  let self.cmd = 
    \'find %(findargs) %(searchpath) %(findexpression) -print0 | sort |'.
    \'xargs -0 grep -Hn %(grepargs) %(pattern) > %(resultsfile)'

  let self.arguments = {
  \  '%(findargs)'       : '',
  \  '%(searchpath)'     : '.',
  \  '%(findexpression)' : '',
  \  '%(grepargs)'       : '',
  \  '%(resultsfile)'    : 'SearchWindowResults',
  \  '%(pattern)'        : ''
  \}

  let self.resultsfile = self.arguments['%(resultsfile)']

  " highlighting for the line containing the match result window
  let self.hi_group_matchline = 'WildMenu'

  " highlighting for the match (search window and result window)
  let self.hi_group_match = 'Search'

  " default mapping for opening a file containing a result in the result window
  let self.key_open_result = '<space>'

  " filetype of the window containing the matches
  let self.filetype = 'autodetect'

  " this function is executed after the buffer of the results window was loaded
  let self.OnLoadResultsWindowBuffer =
        \function('SearchWindow#OnLoadResultsWindowBuffer')

  " this function is executed directly after the search window was loaded
  let self.OnLoadSearchWindowBuffer =
        \function('SearchWindow#OnLoadSearchWindowBuffer')
endfunc

let s:id_generator = 0

" s:instances will store references to each search window created by
" CreateNewInstance; this is used to be able to create internal mappings for a
" search window, since we need a reference to an existing instance to create a
" mapping. if we would't store these references, the created instances go out of
" scope.
let s:instances = {}

"H Implementation

" creates a new object of the SearchWindow class
"
" Usage:
" let swin = SearchWindow#CreateNewInstance()
func! SearchWindow#CreateNewInstance()
  let s:id_generator += 1
  let l:swin = {
        \ 'SetResultsFile'     : function('SearchWindow#SetResultsFile'),
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
        \ 'id'                 : s:id_generator
  \}
  let s:instances[s:id_generator] = l:swin
  call l:swin.Configure()
  return l:swin
endfunc

" call self.OpenSearchResult() for the search window specified by <swin_id>
"
" Arguments:
" swin_id - the id of a search window instance
func s:OpenSearchResult(swin_id)
  call s:instances[a:swin_id].OpenSearchResult()
endfunc

" get the search window instance specified by the id
"
" Arguments:
" swin_id - the id of a search window instance
"
" Return Value:
" the search window instance specified by <swin_id>
func! SearchWindow#GetInstance(swin_id)
  return s:instances[a:swin_id]
endfunc

" set the path of the file containing the list of results
"
" Argument:
" resultfile - path to the resultfile
func! SearchWindow#SetResultsFile(resultsfile) dict
  let self.resultsfile = a:resultsfile
  let self.arguments['%(resultsfile)'] = a:resultsfile
endfunc

" this function is executed directly after the search window was loaded
"
" Comment:
" to have the actual matches highlighted, self.pattern must be set to the search
" pattern provided to the grep command
func SearchWindow#OnLoadSearchWindowBuffer() dict
  exe 'nnoremap <buffer> ' . self.key_open_result .
        \ ' :call <SID>OpenSearchResult('.self.id.')<cr>'

  " open all folds, since folding by syntax does not make much sense
  normal zR

  " prevent user from making changed and vim from complaining about them
  setlocal nomodifiable

  " avoid vim complaining about buffer changes (since the search window buffer
  " is modified outside an will be reloaded by this script when needed)
  setlocal buftype=nofile

  if self.filetype == 'autodetect' && exists('self.ft_detected')
    let &ft = self.ft_detected
  elseif self.filetype != ''
    let &ft = self.filetype
  endif

  " clear existing highlighting for matches and add new ones
  if exists('self.matchid')
    " it may happend, that the file was immediatly unloaded and the match does
    " not exist, so matchdelete will fail; do not bother with it !
    try | call matchdelete(self.matchid) | catch | endtry
  endif
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
  view!
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
  let self.resultsfile = arguments['%(resultsfile)']
  call self.FormatGrepOutput( self.resultsfile, arguments['%(searchpath)'] )
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
" searchpath - the root path of the search
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
func! SearchWindow#FormatGrepOutput(file, searchpath) dict
  let l:lines = readfile(a:file)
  let l:lines_out = []

  call add(l:lines_out, len(l:lines) . " results")

  let l:file = ""
  let l:firstfile = ""
  for l:line in l:lines
    let l:split = matchlist( l:line, '^\(.\{-}\):\(.\{-}\):\(.\{-}\)$' )
    if( len(l:split) < 4 )
      call add(l:lines_out, "")
      call add(l:lines_out, l:line)
      continue
    endif
    let [ l:all, l:filenew, l:linenr, l:match; l:rest ] = l:split
    if l:file !=# l:filenew
      if l:firstfile == "" | let l:firstfile = l:file | endif
      let l:fileabs = ToolBox#GetAbsPath(a:searchpath, l:filenew)
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

  let self.ft_detected = ToolBox#DetectFiletype( l:firstfile )

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
    exec self.splitmods ." sview ". l:resfile
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

  " position the cursor on the line containing the result
  call setpos(".", [0, a:lnr, 0, 0])

  " open all folds
  normal zR

  " highlight the line with the result:
  " exe 'match WildMenu /\%'.a:lnr.'l\S.*\S\s*/'

  " center the line the cursor is on (d.i. the line containing the result)
  normal zz

  if exists("*self.OnLoadResultsWindowBuffer")
    call self.OnLoadResultsWindowBuffer(a:lnr)
  endif
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
