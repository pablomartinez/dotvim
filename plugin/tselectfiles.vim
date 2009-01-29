" tselectfile.vim -- A simplicistic files selector/browser (sort of)
" @Author:      Thomas Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2007-04-16.
" @Last Change: 2007-09-10.
" @Revision:    0.4.453
" GetLatestVimScripts: 1865 1 tselectfiles.vim

if &cp || exists("loaded_tselectfile")
    finish
endif
if !exists('loaded_tlib') || loaded_tlib < 13
    echoerr "tlib >= 0.13 is required"
    finish
endif
let loaded_tselectfile = 4

" Whether to cache directory listings (in memory). (per buffer, global)
" If 0, disable the use of cached file listings all together.
TLet g:tselectfiles_use_cache = 1

" Don't use the cache for directories matching this rx. (per buffer, 
" global)
TLet g:tselectfiles_no_cache_rx = ''

" Retain only files matching this rx. (per window, per buffer, global)
TLet g:tselectfiles_filter_rx = ''

" Use these dirs (a comma separated list, see |globpath()|). (per window, per buffer, global)
" TLet g:tselectfiles_dir = ''

let s:select_files_files = {}

function! s:SNR()
    return matchstr(expand('<sfile>'), '<SNR>\d\+_\zeSNR$')
endf

function! s:SuffixesRx()
    return printf('\(%s\)\$', join(map(split(&suffixes, ','), 'v:val'), '\|'))
endf

if !exists('g:tselectfiles_handlers')
    " \ {'key': 35, 'agent': s:SNR() .'AgentSelect'},
    let g:tselectfiles_handlers = [
                \ {'key':  4, 'agent': s:SNR() .'AgentDeleteFile',      'key_name': '<c-d>', 'help': 'Delete file(s)'},
                \ {'key': 18, 'agent': s:SNR() .'AgentReset'},
                \ {'key': 19, 'agent': 'tlib#agent#EditFileInSplit',    'key_name': '<c-s>', 'help': 'Edit files (split)'},
                \ {'key': 22, 'agent': 'tlib#agent#EditFileInVSplit',   'key_name': '<c-v>', 'help': 'Edit files (vertical split)'},
                \ {'key': 20, 'agent': 'tlib#agent#EditFileInTab',      'key_name': '<c-t>', 'help': 'Edit files (new tab)'},
                \ {'key': 23, 'agent': 'tlib#agent#ViewFile',           'key_name': '<c-w>', 'help': 'View file in window'},
                \ {'key': 21, 'agent': s:SNR() .'AgentRenameFile',      'key_name': '<c-u>', 'help': 'Rename file(s)'},
                \ {'key': 3,  'agent': 'tlib#agent#CopyItems',          'key_name': '<c-c>', 'help': 'Copy file name(s)'},
                \ {'key': 11, 'agent': s:SNR() .'AgentCopyFile',        'key_name': '<c-k>', 'help': 'Copy file(s)'},
                \ {'key': 16, 'agent': s:SNR() .'AgentPreviewFile',     'key_name': '<c-p>', 'help': 'Preview file'},
                \ {'key':  2, 'agent': s:SNR() .'AgentBatchRenameFile', 'key_name': '<c-b>', 'help': 'Batch rename file(s)'},
                \ {'key': 126, 'agent': s:SNR() .'AgentSelectBackups',  'key_name': '~',     'help': 'Select backup(s)'},
                \ {'key': 9,  'agent': 'tlib#agent#ShowInfo',           'key_name': '<c-i>', 'help': 'Show info'},
                \ {'key': 24, 'agent': s:SNR() .'AgentHide',            'key_name': '<c-x>', 'help': 'Hide some files'},
                \ {'display_format': 'filename'},
                \ {'return_agent': 'tlib#agent#ViewFile'},
                \ {'pick_last_item': 0},
                \ ]
                " \ {'key': 15, 'agent': s:SNR() .'AgentOpenDir',         'key_name': '<c-o>', 'help': 'Open dir'},
endif

if !exists('g:tselectfiles_hidden')
    let g:tselectfiles_hidden_rx = '\V\(/.\|/CVS\|/.attic\|.svn\|'. s:SuffixesRx() .'\)\(\[\\/]\|\$\)'
endif

if !exists('g:tselectfiles_favourites')
    if has('win16') || has('win32') || has('win64')
        let g:tselectfiles_favourites = ['c:/', 'd:/']
    else
        let g:tselectfiles_favourites = []
    endif
    if !empty($HOME)
        call add(g:tselectfiles_favourites, $HOME)
    endif
    if !empty($USERPROFILE)
        call add(g:tselectfiles_favourites, $USERPROFILE)
        " call add(g:tselectfiles_favourites, $USERPROFILE .'/desktop/')
    endif
endif


function! s:CacheID() "{{{3
    return s:select_files_dir . s:select_files_pattern
endf


function! s:PrepareSelectFiles(hide)
    " TLogVAR a:hide
    let filter = s:select_files_dir . s:select_files_pattern
    " TLogVAR filter
    let rv = split(globpath(s:select_files_dir, s:select_files_pattern), '\n')
    " TLogVAR rv
    if a:hide
        call filter(rv, 'v:val !~ g:tselectfiles_hidden_rx')
    endif
    " let subset = tlib#var#Get('tselectfiles_filter_rx', 'wbg')
    " if !empty(subset)
    "     call filter(rv, 'v:val =~ subset')
    " endif
    if s:select_files_pattern == '**'
        call sort(filter(rv, '!isdirectory(v:val)'))
    else
        call sort(map(rv, 'isdirectory(v:val) ? v:val."/" : v:val'))
        let rv += g:tselectfiles_favourites
        " call TLogDBG(string(split(s:select_files_dir, '[^\\]\zs,')))
        for phf in split(s:select_files_dir, '[^\\]\zs,')
            let ph = fnamemodify(phf, ':h')
            " TLogVAR ph
            " call TLogDBG(s:select_files_dir)
            if ph != phf
                if ph[-1] !~ '[\/]'
                    let ph .= '/'
                endif
                call insert(rv, ph .'../')
            endif
        endfor
    endif
    return rv
endf


function! s:UseCache() "{{{3
    let use_cache = tlib#var#Get('tselectfiles_use_cache', 'bg')
    let no_cache  = tlib#var#Get('tselectfiles_no_cache_rx', 'bg')
    let rv = use_cache && (empty(no_cache) || s:select_files_dir !~ no_cache)
    " TLogVAR rv
    return rv
endf


function! s:GetFileList(mode, hide)
    if s:UseCache()
        let id = s:CacheID()
        if a:mode =~ '\(!\|\d\)$' || a:mode == 'scan' || !has_key(s:select_files_files, id)
            if a:mode =~ '!$'
                let s:select_files_files = {}
            endif
            " TLogVAR id
            let s:select_files_files[id] = s:PrepareSelectFiles(a:hide)
        endif
        return s:select_files_files[id]
    else
        return s:PrepareSelectFiles(a:hide)
    endif
endf


function! s:AgentPostprocess(world, result)
    let item = resolve(a:result)
    " TLogVAR item
    " TLogDBG len(a:world.list)
    if isdirectory(item)
        let s:select_files_dir = fnamemodify(item, ':p')
        return [s:ResetInputList(a:world, ''), '']
    endif
    return [a:world, a:result]
endf


function! s:AgentOpenDir(world, selected)
    let dir = input('DIR: ', '', 'dir')
    echo
    if dir != ''
        let s:select_files_dir = fnamemodify(dir, ':p')
        return s:ResetInputList(a:world, '')
    endif
    return a:world
endf


" function! s:AgentSelect(world, selected) "{{{3
"     let fname = a:world.GetBaseItem(a:world.prefidx)
"     if !filereadable(fname) && s:UseCache()
"         echom 'TSelectFile: Out-dated cache? File not readable: '. fname
"         return s:ResetInputList(a:world)
"     else
"         call a:world.SelectItem('toggle', a:world.prefidx)
"         " let a:world.state = 'display keepcursor'
"         let a:world.state = 'redisplay'
"         return a:world
"     endif
" endf


function! s:AgentReset(world, selected) "{{{3
    return s:ResetInputList(a:world)
endf


function! s:DeleteFile(file)
    let doit = input('Really delete file "'. a:file .'"? (y/N) ', s:delete_this_file_default)
    echo
    if doit ==? 'y'
        if doit ==# 'Y'
            let s:delete_this_file_default = 'y'
        endif
        call delete(a:file)
        echom 'Delete file: '. a:file
        let bn = bufnr(a:file)
        if bn != -1 && bufloaded(bn)
            let doit = input('Delete corresponding buffer '. bn .' too? (y/N) ')
            if doit ==? 'y'
                exec 'bdelete '. bn
            endif
        endif
    endif
endf


function! s:AgentDeleteFile(world, selected)
    call a:world.CloseScratch()
    let s:delete_this_file_default = ''
    for file in a:selected
        call s:DeleteFile(file)
    endfor
    return s:ResetInputList(a:world)
endf


function! s:Preview(file) "{{{3
    exec 'pedit '. escape(a:file, '%#\ ')
    let s:tselectfiles_previewedfile = a:file
endf


function! s:ClosePreview() "{{{3
    if exists('s:tselectfiles_previewedfile')
        pclose
        unlet! s:tselectfiles_previewedfile
    endif
endf


function! s:AgentPreviewFile(world, selected)
    let file = a:selected[0]
    if !exists('s:tselectfiles_previewedfile') || file != s:tselectfiles_previewedfile
        call s:Preview(file)
        let a:world.state = 'redisplay'
    else
        call s:ClosePreview()
        let a:world.state = 'display'
    endif
    return a:world
endf


function! s:ConfirmCopyMove(query, src, dest)
    echo
    echo 'From: '. a:src
    echo 'To:   '. a:dest
    let ok = input(a:query .'(y/n) ', 'y')
    echo
    return ok[0] ==? 'y'
endf


function! s:CopyFile(src, dest, confirm)
    if a:src != '' && a:dest != '' && (!a:confirm || s:ConfirmCopyMove('Copy now?', a:src, a:dest))
        let fc = readfile(a:src, 'b')
        if writefile(fc, a:dest, 'b') == 0
            echom 'Copy file "'. a:src .'" -> "'. a:dest
        else
            echom 'Failed: Copy file "'. a:src .'" -> "'. a:dest
        endif
    endif
endf


function! s:AgentCopyFile(world, selected)
    for file in a:selected
        let name = input('Copy "'. file .'" to: ', file)
        echo
        call s:CopyFile(file, name, 0)
    endfor
    return s:ResetInputList(a:world)
endf


function! s:RenameFile(file, name, confirm)
    if a:name != '' && (!a:confirm || s:ConfirmCopyMove('Rename now?', a:file, a:name))
        call rename(a:file, a:name)
        echom 'Rename file "'. a:file .'" -> "'. a:name
        if bufloaded(a:file)
            exec 'buffer! '. tlib#arg#Ex(a:file)
            exec 'file! '. tlib#arg#Ex(a:name)
            echom 'Rename buffer: '. a:file .' -> '. a:name
        endif
    endif
endf


function! s:AgentRenameFile(world, selected)
    let s:rename_this_file_pattern = ''
    let s:rename_this_file_subst   = ''
    call a:world.CloseScratch()
    for file in a:selected
        let name = input('Rename "'. file .'" to: ', file)
        echo
        call s:RenameFile(file, name, 0)
    endfor
    return s:ResetInputList(a:world)
endf

function! s:AgentBatchRenameFile(world, selected)
    let pattern = input('Rename pattern (whole path): ')
    if pattern != ''
        echo 'Pattern: '. pattern
        let subst = input('Rename substitution: ')
        if subst != ''
            call a:world.CloseScratch()
            for file in a:selected
                let name = substitute(file, pattern, subst, 'g')
                call s:RenameFile(file, name, 1)
            endfor
        endif
    endif
    echo
    return s:ResetInputList(a:world)
endf


function! s:AgentSelectBackups(world, selected)
    let a:world.filter = s:SuffixesRx()
    let a:worldstate   = 'display'
    return a:world
endf


function! s:ResetInputList(world, ...) "{{{3
    let mode = a:0 >= 1 ? a:1 : 'scan'
    let a:world.state  = 'reset'
    let a:world.base   = s:GetFileList(mode, get(a:world, 'hide', 1))
    let a:world.picked = 0
    return a:world
endf


function! s:AgentHide(world, selected)
    let hidden = get(a:world, 'hide', 1)
    let a:world.hide = hidden ? 0 : 1
    let a:world.state = 'reset'
    return s:ResetInputList(a:world)
endf


function! TSelectFiles(mode, filter)
    " TLogVAR a:mode, a:filter
    let s:select_files_buffer = bufnr('%')
    let s:select_files_mode   = a:mode
    if empty(a:filter)
        let s:select_files_dir = tlib#var#Get('tselectfiles_dir', 'bg', escape(expand('%:p:h'), ','))
    else
        let s:select_files_dir = escape(fnamemodify(a:filter, ':p:h'), ',')
    endif
    " call TLogVAR('s:select_files_dir=', s:select_files_dir)
    let handlers = copy(g:tselectfiles_handlers)
    let handlers += [
                \ {'state': '\<reset\>', 'exec': 'let world.base = '. s:SNR().'GetFileList('. string(a:mode) .', 1)'},
                \ ]
                
    let filter = tlib#var#Get('tselectfiles_filter_rx', 'wbg')
    " TLogVAR filter
    if !empty(filter)
        call add(handlers, {'filter': filter})
    endif
    if a:mode =~ '^n'
        let s:select_files_pattern = '*'
        call add(handlers, {'postprocess': '', 'agent': s:SNR() .'AgentPostprocess'})
    elseif a:mode =~ '^r'
        let s:select_files_pattern = '**'
    else
        echoerr 'TSelectFile: Unknown mode: '. a:mode
    endif
    let fl = s:GetFileList(a:mode, 1)
    " TLogVAR fl
    " let s:select_files_files  = tlib#var#Get('tselect_files_files', 'b', {})
    let fs = tlib#input#List('m', 'Select files', fl, handlers)
    " let b:tselect_files_files = s:select_files_files
    call s:ClosePreview()
    " if !empty(fs)
    "     call tlib#file#With('edit', 'buffer', fs)
    " endif
endf

" :display: :TSelectFiles[!] [DIR]
" Open/delete/rename files in the current directory.
" A [!] forces the commands to rescan the directory. Otherwise a cached 
" value will be used if available.
" You can also type <c-r> to force rescanning a directory, which could 
" be necessary if the file system were changed (e.g. by creating a new 
" file or by some external command)
command! -bang -nargs=? -complete=dir TSelectFiles call TSelectFiles("normal<bang>".v:count, <q-args>)

" Recursively show all files in the current directory and subdirectories 
" (don't show favourites and ".."); don't use this command when you're 
" at /.
" A [!] forces the commands to rescan the directory. Otherwise a cached 
" value will be used if available.
command! -bang -nargs=? -complete=dir TSelectFilesInSubdirs call TSelectFiles("recursive<bang>".v:count, <q-args>)


finish

CHANGES:
0.1
Initial release

0.2
- Copy files
- Renamed TSelectFiles! to TSelectFilesInSubdirs
- Cache file listings (reset by adding a ! to the command or by typing 
<c-r> in the list view)
- g:tselectfiles_use_cache, g:tselectfiles_no_cache: Control the use of 
cached file listings
- If no start argument is provided, the starting directory can also be 
defined via b:tselectfiles_dir and g:tselectfiles_dir (use "." to use 
the current directory); this could be used to quickly select 
project-related files
- Key shortcuts to open files in (vertically) split windows or tabs
- <c-c> now is "Copy file names", <c-k> is "Copy files"

0.3
- Require tlib 0.9
- "Delete file" will ask whether to delete a corresponding buffer too.

0.4
- <c-w> ... View file in original window
- Disabled <c-o> Open dir
- Require tlib >= 0.12
- When renaming a file that's loaded, rename also the buffer.
- You can filter the list of selected files via setting the 
[wbg]:tselectfiles_filter_rx variable.
- Renamed g:tselectfiles_no_cache to g:tselectfiles_no_cache_rx
- [bg]:tselectfiles_use_cache and [bg]:tselectfiles_no_cache_rx can now 
also be set per buffer.
- Renamed some variables from tselectfile_* to tselectfiles_*.
- Can be "suspended" (i.e. you can switch back to the orignal window)

