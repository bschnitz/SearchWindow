" the core of the SearchWindow Plugin
"
" Last Change:	2015-05-31
" Maintainer:	  Benjamin Schnitzler <benjaminschnitzler@googlemail.com>
" License:	    This file is placed in the public domain.
" Comments:     
" · The code in this file shall be at most 80 characters in width

if exists("g:loaded_SearchWindow")
  finish
endif
let g:loaded_SearchWindow = 1

let s:swin = {}

func! SearchWindow#CreateNewInstance()
  let l:instance = copy(s:swin)
  return l:instance
endfunc

func! s:swin.HelloWorlds()
  echo "Hello Worlds!"
endfunc

"H vim: set tw=80 colorcolumn=+1 :
