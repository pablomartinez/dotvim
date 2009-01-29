" Configuración para FuzzyFinder
let g:FuzzyFinderOptions.Base.max_item = 2000
let g:FuzzyFinderOptions.Base.matching_limit = 2000
let g:FuzzyFinderOptions.File.max_item = 2000
let g:FuzzyFinderOptions.File.matching_limit = 2000

" Shortcuts a FuzzyFinder para Rails
" Con F4 buscamos en los ficheros tageados (Rtag!)
" Con C-o buscamos en app/
nnoremap <F4> :FuzzyFinderTaggedFile<CR>
nnoremap <C-o> :FuzzyFinderFile <C-r>=b:rails_root.'/app/'<CR><CR>
" No entiendo porque se queja de "Too many files con esto"
" nnoremap <C-o> :FuzzyFinderFile <C-r>=b:rails_root.'/app/**'<CR><CR>
