" syntax for ht
if exists('b:current_syntax')
  finish
endif

" Some NOTE:
"
" get information of the syntax under the cursor:
" :echo synIDattr(synID(line("."), col("."), 1), "name")
"
"
" Structure  PreProc Identifier  Conditional
" Typedef  Statement Tag Title
" Underlined Delimiter
" Error Define Operator Label Character 
" Directory " WarningMsg

" --- CURL command syntax highlighting
syntax match htCurlStart    ">curl"                contained
syntax match htCurlMethod   /\v\-X\s+[\'A-Za-z]+/  contained 
syntax region htCurlCmd 
    \ start=+>curl+ 
    \ end=/\v^(\s)*$/
    \ contains=htCurlStart,htUrl,htCurlMethod

highlight link htCurlStart        Constant
highlight link htCurlMethod       Function
highlight link htCurlCmd     Delimiter


" --- define basic syntax comment and section ---
syntax match   htComment "#.*$" 
syntax match   htSection "^###"                      contained              
syntax match   htFavorite /\v\s#.*/                  contained              
syntax region  htReplace start=/\v\{\{/ end=/\v\}\}/ contained

highlight link htComment      Comment
highlight link htSection      WarningMsg " Constant 
highlight link htFavorite     Function 
" highlight link htReplace      FoldColumn 
highlight      htReplace      guifg=DarkGray    gui=NONE


" --- define variable with replacement ---
syntax match htValue /\v\s*.+/                       contained contains=htReplace,htComment 
syntax match htKey /\v^([A-Za-z-_])+/                contained 
syntax match htVarChar "^@"                          contained
syntax match htVarCharCfg "^@cfg."                   contained 
syntax match htVarKey /\v^\@([A-Za-z-_])+/           contained contains=htVarChar
syntax match htVarKeyCfg /\v^\@cfg\.([A-Za-z-_])+/   contained contains=htVarCharCfg
syntax match htColon /\v\s*:\s*/                     contained      
syntax match htEqual /\v\s*\=\s*/                    contained  

highlight link htColon        Function 
highlight link htEqual        Constant
highlight link htKey          Keyword
" highlight      htValue        guifg=DarkCyan    gui=italic
highlight link htVarChar      Delimiter
highlight link htVarCharCfg   Keyword
highlight link htVarKey       Delimiter
highlight link htVarKeyCfg    Delimiter


" --- section, headers, query and variable ---
syntax region htSectionFavorite  start=/\v^###(\s#)?.*/                     end=/\n/  contains=htSection,htFavorite
syntax region htHeader           start=/\v^[A-Za-z-_]+\s*:\s*.+/            end=/\n/  contains=htKey,htColon,htValue
syntax region htQuery            start=/\v^[A-Za-z-_]+\s*\=\s*.+/           end=/\n/  contains=htKey,htEqual,htValue
syntax region htVariable         start=/\v^\@([A-Za-z-_])+\s*\=\s*.+/       end=/\n/  contains=htVarChar,htVarKey,htEqual,htValue
syntax region htVariableCfg      start=/\v^\@cfg\.([A-Za-z-_])+\s*\=\s*.+/  end=/\n/  contains=htVarCharCfg,htVarKeyCfg,htEqual,htValue


" --- define the request: method URL HTTP-Version ---
syntax region htRequest 
    \ start=/^\(GET\|POST\|PUT\|DELETE\|HEAD\|OPTIONS\|PATCH|TRACE\)\s\s*h/ 
    \ end=/\n/ 
    \ contains=htUrl,htVersion,htComment 

syntax match htUrl /http[s]\?:\/\/[A-Za-z0-9\/\-\=\._:?%&{}()\]\[]\+/  contained contains=htUrlQuery,htReplace
syntax match htUrlQuery /[?&]/                                         contained 
syntax match htVersion /HTTP\/[0-9]\.[0-9]/                            contained

highlight link htRequest   Function 
highlight link htUrlQuery  Error 
highlight link htVersion   Delimiter
highlight link htUrl       WarningMsg 




" syntax match htHeader /\v^([A-Za-z-])+:\s*.+/       contains=htReplace,htComment 
" syntax match htQuery /\v^([A-Za-z-])+\s*\=\s*.+/    contains=htReplace,htComment

" highlight link htHeader       Delimiter 
" highlight link htQuery        Tag


" syn include @JSON syntax/json.vim
" syn region rJson start=+{+ end=+}+ contains=@JSON fold transparent 

syntax region htJsonBody  start=+{+ end=+}+     contains=htJsonBody
highlight link htJsonBody String

syntax match htJsonBodyFile   /\v^\<.*/ 
highlight link htJsonBodyFile String

syntax region htScript start=+--{%+ end=+--%}+ 
highlight link htScript Tag

syntax region htScriptHttp start=+> {%+ end=+%}+ 
highlight link htScriptHttp Tag

" syntax for ht
let b:current_syntax = "ht"

