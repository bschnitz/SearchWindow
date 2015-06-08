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
" Description:
" Examples to demonstrate and simplify the Usage of the SearchWindow Plugin
" Last Change:	2015-06-07
" Maintainer:	  Benjamin Schnitzler <benjaminschnitzler@googlemail.com>
" License:	    GNU General Public License version 3
" Dependencies: See SearchWindow.vim
" Comments:     See SearchWindow.vim
" Additional Comment:
" · The code in this file shall be at most 80 characters in width

"H Implementation

" creates a search window instance for basic searching
" Arguments:
" key_open_search_window - key(combo) for creating a mapping for opening the
"                          search window
"
" Return Value:
" the search window instance created
func! SearchWindow#Examples#CreateBasicSearch(key_open_search_window)
  " get a new instance of the search window class
  let l:swin = SearchWindow#CreateNewInstance()

  " change the default highlighting for matches (default group is 'Search')
  highlight matched ctermbg=39 ctermfg=black
  let l:swin.hi_group_match = 'matched'

  " set the file where to temporarily store the search results
  " (the default would otherwise be './SearchWindowResults')
  call l:swin.SetResultsFile('/tmp/SearchWindowResults')

  " convenience function for interpreting user input and passing it to the
  " actual search command of the SearchWindow class
  let l:swin.SearchWindow = function("SearchWindow#Examples#Search")

  " create a command to simplify search and a mapping for this command
  let l:open_search_window = '<SID>SearchWindow('.l:swin.id.',''<args>'')'
  exe 'command -nargs=* SearchWindow call ' . l:open_search_window
  exe 'nnoremap '.a:key_open_search_window.' q:iSearchWindow -i '

  return l:swin
endfunc

" creates a search window instance for searching in c/c++ files
"
" Arguments:
" key_open_search_window - key(combo) for creating a mapping for opening the
"                          search window
"
" Return Value:
" the search window instance created
func! SearchWindow#Examples#CreateCppSearch(key_open_search_window)
  " first get a basic search object, which we will extend/modify in here
  let l:swin = SearchWindow#Examples#CreateBasicSearch(a:key_open_search_window)

  " tell find to search for c++ files (by looking on the file extension)
  let l:findregex = '''.*\.\([chit][p+x]\{2\}\|[chi]\{1,2\}\|inl\|tpl\)$'''
  let l:swin.arguments['%(findexpression)'] =
        \ '-regextype sed -iregex '.l:findregex

  " filetype to be set for the search window buffer; otherwise it would be
  " autodetect, which would set the filetype to the filetype of the first file
  " found, which would probably work too, though it would be awkward
  let l:swin.filetype = 'cpp'

  " see SearchWindow#Examples#FormatCppOutputLine
  let l:swin.FormatOutputLine =
        \ function('SearchWindow#Examples#FormatCppOutputLine')

  " -a tells grep not to autodetect if a file is binary; we assume, that the
  " files found by find are not binary; anyways the use can change the flags
  " if experiencing problems
  exe 'nnoremap '.a:key_open_search_window.' q:iSearchWindow -ai '
  return l:swin
endfunc

" Searches for a given pattern and opens the search window with the results
"
" Argument:
" args - a string of the form '<flags> <pattern>'. this will be provided to grep
func! SearchWindow#Examples#Search(args) dict
  " search for the <flags> and the <pattern> from the <args> string
  let l:matchlist = matchlist(a:args, '\(\S\+\)\s*\(\S.*\)\{0,1\}')

  " no arguments were provided, error & exit
  if len(l:matchlist) == 0
    echoerr "Not enough arguments provided for search."
    return
  endif


  " get the <flags> and the <pattern> from the <args> string
  let [l:whole, l:flags, l:pattern; l:rest] = l:matchlist
  if l:pattern == ''        " this means, only one argument was provided,
    let l:pattern = l:flags " take it as search pattern
    let l:flags = ''
  endif

  " the pattern is also of interest for the search window instance, 
  " since it will be used for highlighting:
  let self.pattern = l:pattern

  " prevent the shell from mangling the pattern (put it in '')
  let l:pattern = "'".l:pattern."'"

  " the call to the search; the first argument is a dictionary containing the
  " configuration of the search command, the second tells the search window, if
  " we want to stay in the current window (1) or move to the search window (0)
  " the third tells the command to open the search window, if it is not open
  let l:arguments = { '%(pattern)' : l:pattern, '%(grepargs)' : l:flags }
  call self.Search( l:arguments, 0, 1 )
endfunc

" invokes self.SearchWindow(args) on the search window specified by <swin_id>
"
" Arguments:
" swin_id - the id of the specified search window instance
" args    - an argument string for the grep command (see
"           SearchWindow#Examples#Search)
"
" Comment:
" we have to use GetInstance, since we do not have a script reference to the
" search window instance we want to use for searching.
func! s:SearchWindow(swin_id, args)
  call SearchWindow#GetInstance(a:swin_id).SearchWindow(a:args)
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
func! SearchWindow#Examples#FormatCppOutputLine(line)
  " close unclosed multiline comments (/* ...)
  let l:pattern = '\(\/\*\(\(\*\/\)\@!.\)*\)$'
  let l:line = substitute(a:line, l:pattern, '\1 *** closed comment */', '')

  " close '#if 0'
  let l:line = substitute(l:line,'\(#if\s*0.*\)$' , '\1 #', '')

  return l:line
endfunc

"H vim: set tw=80 colorcolumn=+1 :
