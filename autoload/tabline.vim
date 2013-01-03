" Variables: {{{

let s:DEFAULT_OPTIONS = {
      \ 'min-width': 0,
      \ 'max-width': 40,
      \ 'min-width-resized': 15,
      \ 'scroll-off': 5,
      \ 'ellipsis-text': '...',
      \ 'divide-equel': 0
      \ }

let s:tabLineTabs = []

" }}} Variables


" Main Functions: {{{

function! tabline#build() "{{{
  " NOTE: left/right padding of each tab was hard coded as 1 space.
  " NOTE: require Vim 7.3 strwidth() to display fullwidth text correctly.

  " settings
  let tabMinWidth = 0
  let tabMaxWidth = 40
  let tabMinWidthResized = 15
  let tabScrollOff = 5
  let tabEllipsis = '…'
  let tabDivideEquel = 0

  let s:tabLineTabs = []

  let tabCount = tabpagenr('$')
  let tabSel = tabpagenr()

  " fill s:tabLineTabs with {n, filename, split, flag} for each tab
  for i in range(tabCount)
    let tabnr = i + 1
    let buflist = tabpagebuflist(tabnr)
    let winnr = tabpagewinnr(tabnr)
    let bufnr = buflist[winnr - 1]

    let filename = bufname(bufnr)
    let filename = fnamemodify(filename, ':p:t')
    let buftype = getbufvar(bufnr, '&buftype')
    if filename == ''
      if buftype == 'nofile'
        let filename .= '[Scratch]'
      else
        let filename .= '[New]'
      endif
    endif
    let split = ''
    let winCount = tabpagewinnr(tabnr, '$')
    if winCount > 1   " has split windows
      let split .= winCount
    endif
    let flag = ''
    if getbufvar(bufnr, '&modified')  " modified
      let flag .= '+'
    endif
    if strlen(flag) > 0 || strlen(split) > 0
      let flag .= ' '
    endif

    call add(s:tabLineTabs, {'n': tabnr, 'split': split, 'flag': flag, 'filename': filename})
  endfor

  " variables for final oupout
  let s = ''
  let l:tabLineTabs = deepcopy(s:tabLineTabs)

  " overflow adjustment
  " 1. apply min/max tabWidth option
  if s:TabLineTotalLength(l:tabLineTabs) > &columns
    unlet i
    for i in l:tabLineTabs
      let tabLength = s:CalcTabLength(i)
      if tabLength < tabMinWidth
        let i.filename .= repeat(' ', tabMinWidth - tabLength)
      elseif tabMaxWidth > 0 && tabLength > tabMaxWidth
        let reserve = tabLength - StrWidth(i.filename) + StrWidth(tabEllipsis)
        if tabMaxWidth > reserve
          let i.filename = StrCrop(i.filename, (tabMaxWidth - reserve), '~') . tabEllipsis
        endif
      endif
    endfor
  endif
  " 2. try divide each tab equal-width
  if tabDivideEquel
    if s:TabLineTotalLength(l:tabLineTabs) > &columns
      let divideWidth = max([tabMinWidth, tabMinWidthResized, &columns / tabCount, StrWidth(tabEllipsis)])
      unlet i
      for i in l:tabLineTabs
        let tabLength = s:CalcTabLength(i)
        if tabLength > divideWidth
          let i.filename = StrCrop(i.filename, divideWidth - StrWidth(tabEllipsis), '~') . tabEllipsis
        endif
      endfor
    endif
  endif
  " 3. ensure visibility of current tab
  let rhWidth = 0
  let t = tabCount - 1
  let rhTabStart = min([tabSel - 1, tabSel - tabScrollOff])
  while t >= max([rhTabStart, 0])
    let tab = l:tabLineTabs[t]
    let tabLength = s:CalcTabLength(tab)
    let rhWidth += tabLength
    let t -= 1
  endwhile
  while rhWidth >= &columns
    let tab = l:tabLineTabs[-1]
    let tabLength = s:CalcTabLength(tab)
    let lastTabSpace = &columns - (rhWidth - tabLength)
    let rhWidth -= tabLength
    if rhWidth > &columns
      call remove(l:tabLineTabs, -1)
    else
      " add special flag (will be removed later) indicating that how many
      " columns could be used for last displayed tab.
      if tabSel <= tabScrollOff || tabSel < tabCount - tabScrollOff
        let tab.flag .= '>' . lastTabSpace
      endif
    endif
  endwhile

  " final ouput
  unlet i
  for i in l:tabLineTabs
    let tabnr = i.n

    let split = ''
    if strlen(i.split) > 0
      if tabnr == tabSel
        let split = '%#TabLineSplitNrSel#' . i.split .'%#TabLineSel#'
      else
        let split = '%#TabLineSplitNr#' . i.split .'%#TabLine#'
      endif
    endif

    let text = ' ' . split . i.flag . i.filename . ' '

    if i.n == l:tabLineTabs[-1].n
        if match(i.flag, '>\d\+') > -1 || i.n < tabCount
        let lastTabSpace = matchstr(i.flag, '>\zs\d\+')
        let i.flag = substitute(i.flag, '>\d\+', '', '')
        if lastTabSpace <= strlen(i.n)
          if lastTabSpace == 0
            let s = strpart(s, 0, strlen(s) - 1)
          endif
          let s .= '%#TabLineMore#>'
          continue
        else
          let text = ' ' . i.split . i.flag . i.filename . ' '
          let text = StrCrop(text, (lastTabSpace - strlen(i.n) - 1), '~') . '%#TabLineMore#>'
          let text = substitute(text, ' ' . i.split, ' ' . split, '')
        endif
        endif
    endif

    let s .= '%' . tabnr . 'T'  " start of tab N

    if tabnr == tabSel
      let s .= '%#TabLineNrSel#' . tabnr . '%#TabLineSel#'
    else
      let s .= '%#TabLineNr#' . tabnr . '%#TabLine#'
    endif

    let s .= text

  endfor

  let s .= '%#TabLineFill#%T'
  if exists('s:tabLineResult') && s:tabLineResult !=# s
    let s:tabLineNeedRedraw = 1
  endif
  let s:tabLineResult = s
  return s
endfunction "}}}

function! tabline#tabs() "{{{
  return s:tabLineTabs
endfunction "}}}

" }}} Main Functions


" Utils: {{{

function! s:option(key) "{{{
  return get(g:, key, get(s:DEFAULT_OPTIONS, key))
endfunction "}}}


function! s:CalcTabLength(tab)
  return strlen(a:tab.n) + 2 + strlen(a:tab.split) + strlen(a:tab.flag) + StrWidth(a:tab.filename)
endfunction


function! s:TabLineTotalLength(dict)
  let length = 0
  for i in (a:dict)
    let length += strlen(i.n) + 2 + strlen(i.split) + strlen(i.flag) + StrWidth(i.filename)
  endfor
  return length
endfunction

" }}} Utils
