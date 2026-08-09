; Verse indents.scm for nvim-treesitter

; Colon-block forms -- fire even when block is empty (no body typed yet)
((macro_call
  (block "macro:")) @indent.begin
 (#set! indent.immediate 1))

((of_expression
  (block "macro:")) @indent.begin
 (#set! indent.immediate 1))

((function_declaration
  (block)) @indent.begin
 (#set! indent.immediate 1))

; else: header sits at the same level as surrounding block content
(macro_call (else_keyword) @indent.branch)

; Completed multi-line argument lists
(argument_list) @indent.begin

; In-progress call (ERROR with unclosed paren/brace -- no argument_list node yet)
((ERROR "(" @_open) @indent.begin
  (#set! indent.immediate 1))
((ERROR "{" @_open) @indent.begin
  (#set! indent.immediate 1))

; Closing delimiters go back to opener indent level.
; Note: ")" is intentionally omitted -- a lone ")" on its own line keeps the
; hanging indent of its argument_list so `Call(<CR>)` gives an indented body.
[
  "}"
  "]"
] @indent.branch
