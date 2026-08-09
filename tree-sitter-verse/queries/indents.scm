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

; In-progress argument list (ERROR state while typing)
(ERROR
  "(" @indent.align
  (#set! indent.open_delimiter "(")
  (#set! indent.close_delimiter ")")
  .
  (_))

; In-progress curly block (ERROR state while typing)
(ERROR
  "{" @indent.align
  (#set! indent.open_delimiter "{")
  (#set! indent.close_delimiter "}")
  .
  (_))

; Closing delimiters go back to opener indent level
[
  "}"
  ")"
  "]"
] @indent.branch
