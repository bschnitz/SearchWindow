### Search Window - search for and list patterns from files

#### DESCRIPTION

Search Window enables you to search for a pattern in a specified list of files.
So basically it is very similar to `:vimgrep`, but it aims to be much more
flexible and configurable and it provides a nice way of listing matches in a
window and the possibility to navigate to them.

![Screenshot](https://github.com/bschnitz/SearchWindow/tree/various/screenshot.png)

#### INSTALLATION

You may use [Vundle][1] to install Search Window.

#### QUICK START

1. Put the following into your .vimrc

```vim
   " create a search window instance, '<F9>' will give you a search prompt
   SearchWindow#Examples#CreateBasicSearch('<F9>')
```

2. move to a directory containing files to search for a pattern and open a new
   instance of vim there

3. pressing `<F9>` will give you the following prompt: `:SearchWindow -i `, enter
   a search pattern (standard 'grep' search pattern) and hit return

Upon completion of these steps, a new window, displaying a list with the search
results, ordered by file and order of appearance, will be show at the bottom of.
the screen. It has focus and allows you to jump to matches by moving the cursor
on a match and pressing `<space>`.

#### WHERE TO GET THE REST OF THE DOCUMENTATION

Use `:help swin` from within vim (after installation). You may also look at the
source code, which is well documented.

#### LICENSE

Tool Box is licensed under version 3 of the GNU General Public License.

#### CONTACT

Benjamin Schnitzler `benjamin.schnitzler+searchwindow@googlemail.com` .

[1]: https://github.com/gmarik/Vundle.vim
