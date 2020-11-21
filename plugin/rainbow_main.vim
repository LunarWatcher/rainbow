" Copyright 2013 LuoChen (luochen1990@gmail.com). Licensed under the Apache License 2.0.

if exists('s:rainbow_loaded')
    finish
endif

if !exists('g:rainbow_list')
    let g:rainbow_blacklist = ["nerdtree", "startify"] 
elseif exists('g:rainbow_list') && exists('g:rainbow_blacklist')
    echoerr "Dunno what you're trying to pull here, but you can't have both rainbow_list and rainbow_blacklist. For logical reasons,  rainbow_blacklist will be preferred"
endif
let s:rainbow_loaded = 1

" Internal {{{
fun s:trim(s)
    return substitute(a:s, '\v^\s*(.{-})\s*$', '\1', '')
endfun

fun s:concat(strs)
    return join(filter(a:strs, "v:val !~ '^[ ]*$'"), ',')
endfun

fun s:resolve_parenthesis_with(init_state, p)
    let [paren, contained, containedin, contains_prefix, contains, op] = a:init_state
    let p = (type(a:p) == type([])) ? ((len(a:p) == 3) ? printf('start=#%s# step=%s end=#%s#', a:p[0], op, a:p[-1]) : printf('start=#%s# end=#%s#', a:p[0], a:p[-1])) : a:p "NOTE: preprocess the old style parentheses config

    let ls = split(p, '\v%(%(start|step|end)\=(.)%(\1@!.)*\1[^ ]*|\w+%(\=[^ ]*)?) ?\zs', 0)
    for s in ls
        let [k, v] = [matchstr(s, '^[^=]\+\ze\(=\|$\)'), matchstr(s, '^[^=]\+=\zs.*')]
        if k == 'step'
            let op = s:trim(v)
        elseif k == 'contains_prefix'
            let contains_prefix = s:trim(v)
        elseif k == 'contains'
            let contains = s:concat([contains, s:trim(v)])
        elseif k == 'containedin'
            let containedin = s:concat([containedin, s:trim(v)])
        elseif k == 'contained'
            let contained = 1
        else
            let paren .= s
        endif
    endfor
    let rst = [paren, contained, containedin, contains_prefix, contains, op]
    "echom json_encode(rst)
    return rst
endfun

fun s:resolve_parenthesis_from_config(config)
    return s:resolve_parenthesis_with(['', 0, '', a:config.contains_prefix, '', a:config.operators], a:config.parentheses_options)
endfun

fun s:synID(prefix, group, lv, id)
    return a:prefix.'_lv'.a:lv.'_'.a:group.a:id
endfun

fun s:synGroupID(prefix, group, lv)
    return a:prefix.a:group.'_lv'.a:lv
endfun

fun rainbow_main#syn(config)
    let conf = a:config
    let prefix = conf.syn_name_prefix
    let cycle = conf.cycle

    let glob_paran_opts = s:resolve_parenthesis_from_config(conf)
    let b:rainbow_loaded = cycle
    for id in range(len(conf.parentheses))
        let [paren, contained, containedin, contains_prefix, contains, op] = s:resolve_parenthesis_with(glob_paran_opts, conf.parentheses[id])
        for lv in range(cycle)
            let lv2 = ((lv + cycle - 1) % cycle)
            let [rid, pid, gid2] = [s:synID(prefix, 'r', lv, id), s:synID(prefix, 'p', lv, id), s:synGroupID(prefix, 'Regions', lv2)]

            if len(op) > 2
                exe 'syn match '.s:synID(prefix, 'o', lv, id).' '.op.' containedin='.s:synID(prefix, 'r', lv, id).' contained'
            endif

            let real_contained = (lv == 0)? (contained? 'contained ' : '') : 'contained '
            let real_containedin = (lv == 0)? s:concat([containedin, '@'.gid2]) : '@'.gid2
            let real_contains = s:concat([contains_prefix, contains])
            exe 'syn region '.rid.' matchgroup='.pid.' '.real_contained.'containedin='.real_containedin.' contains='.real_contains.' '.paren
        endfor
    endfor
    for lv in range(cycle)
        exe 'syn cluster '.s:synGroupID(prefix, 'Regions', lv).' contains='.join(map(range(len(conf.parentheses)), 's:synID(prefix, "r", lv, v:val)'), ',')
        exe 'syn cluster '.s:synGroupID(prefix, 'Parentheses', lv).' contains='.join(map(range(len(conf.parentheses)), 's:synID(prefix, "p", lv, v:val)'), ',')
        exe 'syn cluster '.s:synGroupID(prefix, 'Operators', lv).' contains='.join(map(range(len(conf.parentheses)), 's:synID(prefix, "o", lv, v:val)'), ',')
    endfor
    exe 'syn cluster '.prefix.'Regions contains='.join(map(range(cycle), '"@".s:synGroupID(prefix, "Regions", v:val)'), ',')
    exe 'syn cluster '.prefix.'Parentheses contains='.join(map(range(cycle), '"@".s:synGroupID(prefix, "Parentheses", v:val)'), ',')
    exe 'syn cluster '.prefix.'Operators contains='.join(map(range(cycle), '"@".s:synGroupID(prefix, "Operators", v:val)'), ',')
    if has_key(conf, 'after') | for cmd in conf.after | exe cmd | endfor | endif
endfun

fun rainbow_main#syn_clear(config)
    let conf = a:config
    let prefix = conf.syn_name_prefix

    for id in range(len(conf.parentheses))
        for lv in range(conf.cycle)
            let [rid, oid] = [s:synID(prefix, 'r', lv, id), s:synID(prefix, 'o', lv, id)]
            exe 'syn clear '.rid
            exe 'syn clear '.oid
        endfor
    endfor
endfun

fun rainbow_main#hi(config)
    let conf = a:config
    let prefix = conf.syn_name_prefix

    for id in range(len(conf.parentheses))
        for lv in range(conf.cycle)
            let [pid, oid] = [s:synID(prefix, 'p', lv, id), s:synID(prefix, 'o', lv, id)]
            let ctermfg = conf.ctermfgs[lv % len(conf.ctermfgs)]
            let guifg = conf.guifgs[lv % len(conf.guifgs)]
            let cterm = conf.cterms[lv % len(conf.cterms)]
            let gui = conf.guis[lv % len(conf.guis)]
            let hi_style = 'ctermfg='.ctermfg.' guifg='.guifg.(len(cterm) > 0 ? ' cterm='.cterm : '').(len(gui) > 0 ? ' gui='.gui : '')
            exe 'hi '.pid.' '.hi_style
            exe 'hi '.oid.' '.hi_style
        endfor
    endfor
endfun

fun rainbow_main#hi_clear(config)
    let conf = a:config
    let prefix = conf.syn_name_prefix

    for id in range(len(conf.parentheses))
        for lv in range(conf.cycle)
            let [pid, oid] = [s:synID(prefix, 'p', lv, id), s:synID(prefix, 'o', lv, id)]
            exe 'hi clear '.pid
            exe 'hi clear '.oid
        endfor
    endfor
endfun

" }}}

" Functions {{{

let s:rainbow_conf = {
\    'guifgs': ['royalblue3', 'darkorange3', 'seagreen3', 'firebrick'],
\    'ctermfgs': ['lightblue', 'lightyellow', 'lightcyan', 'lightmagenta'],
\    'guis': [''],
\    'cterms': [''],
\    'operators': '_,_',
\    'contains_prefix': 'TOP',
\    'parentheses_options': '',
\    'parentheses': ['start=/(/ end=/)/ fold', 'start=/\[/ end=/\]/ fold', 'start=/{/ end=/}/ fold'],
\    'separately': {
\        '*': {},
\        'markdown': {
\            'parentheses_options': 'containedin=markdownCode contained',
\        },
\        'lisp': {
\            'guifgs': ['royalblue3', 'darkorange3', 'seagreen3', 'firebrick', 'darkorchid3'],
\        },
\        'haskell': {
\            'parentheses': ['start=/(/ end=/)/ fold', 'start=/\[/ end=/\]/ fold', 'start=/\v\{\ze[^-]/ end=/}/ fold'],
\        },
\        'ocaml': {
\            'parentheses': ['start=/(\ze[^*]/ end=/)/ fold', 'start=/\[/ end=/\]/ fold', 'start=/\[|/ end=/|\]/ fold', 'start=/{/ end=/}/ fold'],
\        },
\        'tex': {
\            'parentheses_options': 'containedin=texDocZone',
\            'parentheses': ['start=/(/ end=/)/', 'start=/\[/ end=/\]/'],
\        },
\        'vim': {
\            'parentheses_options': 'containedin=vimFuncBody,vimExecute',
\            'parentheses': ['start=/(/ end=/)/', 'start=/\[/ end=/\]/', 'start=/{/ end=/}/ fold'],
\        },
\        'xml': {
\            'syn_name_prefix': 'xmlRainbow',
\            'parentheses': ['start=/\v\<\z([-_:a-zA-Z0-9]+)(\s+[-_:a-zA-Z0-9]+(\=("[^"]*"|'."'".'[^'."'".']*'."'".'))?)*\>/ end=#</\z1># fold'],
\        },
\        'xhtml': {
\            'parentheses': ['start=/\v\<\z([-_:a-zA-Z0-9]+)(\s+[-_:a-zA-Z0-9]+(\=("[^"]*"|'."'".'[^'."'".']*'."'".'))?)*\>/ end=#</\z1># fold'],
\        },
\        'html': {
\            'parentheses': ['start=/\v\<((script|style|area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr)[ >])@!\z([-_:a-zA-Z0-9]+)(\s+[-_:a-zA-Z0-9]+(\=("[^"]*"|'."'".'[^'."'".']*'."'".'|[^ '."'".'"><=`]*))?)*\>/ end=#</\z1># fold'],
\        },
\        'perl': {
\            'syn_name_prefix': 'perlBlockFoldRainbow',
\        },
\        'php': {
\            'syn_name_prefix': 'phpBlockRainbow',
\            'contains_prefix': '',
\            'parentheses': ['start=/(/ end=/)/ containedin=@htmlPreproc contains=@phpClTop', 'start=/\[/ end=/\]/ containedin=@htmlPreproc contains=@phpClTop', 'start=/{/ end=/}/ containedin=@htmlPreproc contains=@phpClTop', 'start=/\v\<((area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr)[ >])@!\z([-_:a-zA-Z0-9]+)(\s+[-_:a-zA-Z0-9]+(\=("[^"]*"|'."'".'[^'."'".']*'."'".'|[^ '."'".'"><=`]*))?)*\>/ end=#</\z1># fold contains_prefix=TOP'],
\        },
\        'stylus': {
\            'parentheses': ['start=/{/ end=/}/ fold contains=@colorableGroup'],
\        },
\        'css': 0,
\        'sh': 0,
\    }
\}

fun s:eq(x, y)
    return type(a:x) == type(a:y) && a:x == a:y
endfun

fun s:gcd(a, b)
    let [a, b, t] = [a:a, a:b, 0]
    while b != 0
        let t = b
        let b = a % b
        let a = t
    endwhile
    return a
endfun

fun s:lcm(a, b)
    return (a:a / s:gcd(a:a, a:b)) * a:b
endfun

fun rainbow_main#gen_config(ft)
    let g = exists('g:rainbow_conf')? g:rainbow_conf : {}
    "echom 'g:rainbow_conf:' string(g)
    let s = get(g, 'separately', {})
    "echom 'g:rainbow_conf.separately:' string(s)
    let dft_conf = extend(copy(s:rainbow_conf), g) | unlet dft_conf.separately
    "echom 'default config options:' string(dft_conf)
    let dx_conf = s:rainbow_conf.separately['*']
    "echom 'default star config:' string(dx_conf)
    let ds_conf = get(s:rainbow_conf.separately, a:ft, dx_conf)
    "echom 'default separately config:' string(ds_conf)
    let ux_conf = get(s, '*', ds_conf)
    "echom 'user star config:' string(ux_conf)
    let us_conf = get(s, a:ft, ux_conf)
    "echom 'user separately config:' string(us_conf)
    let af_conf = (s:eq(us_conf, 'default') ? ds_conf : us_conf)
    "echom 'almost finally config:' string(af_conf)
    if s:eq(af_conf, 0)
        return 0
    else
        let conf = extend(extend({'syn_name_prefix': substitute(a:ft, '\v\A+(\a)', '\u\1', 'g').'Rainbow'}, dft_conf), af_conf)
        let conf.cycle = (has('gui_running') || (has('termguicolors') && &termguicolors)) ? s:lcm(len(conf.guifgs), len(conf.guis)) : s:lcm(len(conf.ctermfgs), len(conf.cterms))
        return conf
    endif
endfun

fun rainbow_main#gen_configs(ft)
    return filter(map(split(a:ft, '\v\.'), 'rainbow_main#gen_config(v:val)'), 'type(v:val) == type({})')
endfun

fun rainbow_main#allowedToRun(auto = 0)
    if a:auto == 0
        return 1
    endif

    if exists('g:rainbow_blacklist') && index(g:rainbow_blacklist, &filetype) != -1
        return 0
    endif
    return 1
endfun

fun rainbow_main#load(auto = 0)
    if rainbow_main#allowedToRun(a:auto) == 0
        return
    endif

    let b:rainbow_confs = rainbow_main#gen_configs(&filetype)
    for conf in b:rainbow_confs
        call rainbow_main#syn(conf)
        call rainbow_main#hi(conf)
    endfor
endfun

fun rainbow_main#clear(auto = 0)
    if rainbow_main#allowedToRun(a:auto) == 0
        return
    endif
    if !exists('b:rainbow_confs') | return | endif
    for conf in b:rainbow_confs
        call rainbow_main#hi_clear(conf)
        call rainbow_main#syn_clear(conf)
    endfor
    unlet b:rainbow_confs
endfun

fun rainbow_main#toggle(auto = 0)
    if exists('b:rainbow_confs')
        call rainbow_main#clear(a:auto)
    else
        call rainbow_main#load(a:auto)
    endif
endfun

fun s:getRainbowList()
    if exists('g:rainbow_blacklist')
        " Run it on everything if we have a blacklist.
        return '*'
    else
        " Otherwise, return the whitelist
        return join(g:rainbow_list, ',')
    endif
endfun

" }}}

command! RainbowToggle call rainbow_main#toggle()
command! RainbowToggleOn call rainbow_main#load()
command! RainbowToggleOff call rainbow_main#clear()

if (exists('g:rainbow_active') && g:rainbow_active)
    let s:rainbowList = s:getRainbowList()
    exec 'auto syntax ' . s:rainbowList . ' call rainbow_main#load(1)'
    exec 'auto colorscheme ' . s:rainbowList . ' call rainbow_main#load(1)'
endif
