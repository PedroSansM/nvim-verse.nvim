; ===========================================================================
; Verse tree-sitter highlights
; ===========================================================================

; ---------------------------------------------------------------------------
; Comments
; ---------------------------------------------------------------------------

(line_comment) @comment @spell
(block_comment) @comment @spell
(indent_comment) @comment @spell

; ---------------------------------------------------------------------------
; Literals
; ---------------------------------------------------------------------------

(string
  ["\"" "\""] @string)
(string_fragment) @string
(escape_sequence) @string.escape
(string_template
  ["{" "}"] @punctuation.special)
(string_template
  (identifier) @variable)
(char) @string
(integer) @number
(float) @number
(logic_literal) @boolean
(path_literal) @string.special.path

; ---------------------------------------------------------------------------
; Functions and methods
; ---------------------------------------------------------------------------

; Free function declarations
(function_declaration
  name: (identifier) @function)

; Method / extension function declared on a receiver:
;   (Receiver: Type).MethodName(...)
(function_declaration
  name: (field_expression
    field: (identifier) @function.method
    (#set! "priority" 200)))

; Constructor-like function (has <constructor> attribute)
(function_declaration
  name: (_) @constructor
  name: (_
    attributes: (attributes
      (identifier) @_attr
      (#eq? @_attr "constructor"))))

; Function calls
(function_call
  function: (identifier) @function.call)

(function_call
  function: (field_expression
    field: (identifier) @function.method.call
    (#set! "priority" 200)))

; Parametric types in type_hint position: awaitable(), awaitable(int), etc.
(declaration
  type_hint: (function_call
    function: (identifier) @type))

(declaration
  type_hint: (function_call
    function: (field_expression
      field: (identifier) @type)))

; Type arguments inside parametric type hints
(declaration
  type_hint: (function_call
    arguments: (argument_list
      (identifier) @type)))

; ---------------------------------------------------------------------------
; Variables and constants
; ---------------------------------------------------------------------------

; Inferred / typed declaration — treat PascalCase as constants, others as vars
(declaration
  (var_keyword) @keyword
  lhs: "("*
  lhs: (identifier) @variable)

; var after @decorator parsed as ERROR — still treat LHS as variable
(declaration
  (ERROR) @keyword
  lhs: (identifier) @variable)

(declaration
  lhs: "("*
  lhs: (identifier) @constant)

; set expression LHS / RHS
(set_expression
  lhs: (identifier) @variable)
(set_expression
  lhs: (field_expression
    field: (identifier) @variable.member))
(set_expression
  rhs: (identifier) @variable)

; Receiver in extension method — (Self: MyClass)
(function_declaration
  name: (field_expression
    target: (_
      (declaration
        lhs: (identifier) @variable.parameter))))

; ---------------------------------------------------------------------------
; Types
; ---------------------------------------------------------------------------

; Type hints in declarations
(declaration
  type_hint: (identifier) @type)

; Type hint in parentheses (field query broken for paren case): Foo : (\n  bar) = ...
; Match ":" "(" identifier ")" structurally to avoid capturing lhs-in-parens
(declaration ":" "(" (identifier) @type ")")

; Return types in function declarations
(function_declaration
  ret_type: (identifier) @type)

; Map key/value type annotations  [KeyType]ValueType
(map_container
  key: (identifier) @type)
(map_container
  value: (identifier) @type)

; Array element type  []ElemType
(array_container
  value: (identifier) @type)

; Optional / failure-check type  ?SomeType
(unary_expression
  operator: "?"
  operand: (identifier) @type)

; Type-check unary   :SomeType
(unary_expression
  operator: ":"
  operand: (identifier) @type)

; Built-in primitive types
; (declaration
;   type_hint: (identifier) @type.builtin
;   (#match? @type.builtin "^(void|string|int|float|logic|char|type|agent|player|creative_device|entity|component)$"))
; (function_declaration
;   ret_type: (identifier) @type.builtin
;   (#match? @type.builtin "^(void|string|int|float|logic|char|type|agent|player|creative_device|entity|component)$"))
; (map_container
;   key: (identifier) @type.builtin
;   (#match? @type.builtin "^(void|string|int|float|logic|char|type|agent|player|creative_device|entity|component)$"))
; (map_container
;   value: (identifier) @type.builtin
;   (#match? @type.builtin "^(void|string|int|float|logic|char|type|agent|player|creative_device|entity|component)$"))
; (array_container
;   value: (identifier) @type.builtin
;   (#match? @type.builtin "^(void|string|int|float|logic|char|type|agent|player|creative_device|entity|component)$"))

; ---------------------------------------------------------------------------
; Attributes  <public>, <private>, <internal>, <computes>, <transacts>, …
; ---------------------------------------------------------------------------

(at_attributes
  "@" @attribute
  (identifier) @attribute)

(at_attributes
  "@" @attribute
  (macro_call
    macro: (identifier) @attribute
    (#set! "priority" 200)))

(attributes
  ["<" ">"] @attribute)

(attributes
  (identifier) @attribute)

; ---------------------------------------------------------------------------
; "is:" block-assignment keyword
; ---------------------------------------------------------------------------

(is_declaration
  lhs: (identifier) @variable)
(is_declaration
  (is_keyword) @keyword.operator)

; "of:" operator — same group as is:
(of_expression
  "of" @keyword.operator)
(of_expression
  lhs: (identifier) @function.call)

; ---------------------------------------------------------------------------
; Type/class definition keywords — used as the RHS of := declarations
; ---------------------------------------------------------------------------

; class, enum, interface, module, struct, tuple, type  (as macro names in := rhs)
(declaration
  lhs: "("*
  lhs: (identifier) @type
  rhs: (macro_call
    macro: (identifier) @_kw
    (#match? @_kw "^(class|enum|interface|module|struct|tuple|type)$")))

(declaration
  rhs: (macro_call
    macro: (identifier) @keyword
    (#match? @keyword "^(class|enum|interface|module|struct|tuple|type)$")))

; Supertype / interface list in arguments — class(MySupertype)
(declaration
  rhs: (macro_call
    macro: (identifier) @_kw
    (#match? @_kw "^(class|enum|interface|struct)$")
    arguments: (argument_list
      (identifier) @type)))

; Enum member declarations — bare identifiers in the body of enum:
(macro_call
  macro: (identifier) @_kw
  (#eq? @_kw "enum")
  (block
    (identifier) @constant))

; Bare expression-statement identifiers in do/then/else/block/option/defer/array bodies
(macro_call
  macro: (identifier) @_macro
  (#match? @_macro "^(do|then|else|block|option|defer|array)$")
  (block
    (identifier) @variable))

; return <identifier>
(return_expression
  (identifier) @variable)

; for Index->Item : Array — index variable on the LHS of ->
(thin_arrow_expression
  lhs: (identifier) @variable)

; for: Item : Collection — collection is a variable, not a type
(macro_call
  macro: (identifier) @_for
  (#eq? @_for "for")
  (block
    (declaration
      type_hint: (identifier) @variable)))

; Names imported in using { Name } or using { Name.Sub } (non-field_expression case)
(macro_call
  macro: (identifier) @_using
  (#eq? @_using "using")
  (block (identifier) @type))

; ---------------------------------------------------------------------------
; ERROR recovery — loose tokens when the root ERROR wraps the whole file
; ---------------------------------------------------------------------------

; "Name<attrs> := class/module/etc." inside root ERROR (no anchors — attributes may intervene)
(ERROR
  (identifier) @type
  ":="
  (identifier) @keyword
  (#match? @keyword "^(module|class|enum|interface|struct|tuple|type)$"))

; Function name inside ERROR: identifier immediately followed by attributes then "("
(ERROR
  (identifier) @function
  (attributes)
  "(")

; void as a standalone return type token inside ERROR
; (ERROR
;   ":"
;   (identifier) @type.builtin
;   (#eq? @type.builtin "void")
;   "=")

; Any identifier that IS a type-defining keyword, regardless of context
((identifier) @keyword
  (#match? @keyword "^(module|class|enum|interface|struct|tuple|type)$"))

; ---------------------------------------------------------------------------
; Macro keywords
; ---------------------------------------------------------------------------

; Concurrency / flow control macros
(macro_call
  macro: (identifier) @keyword
  (#match? @keyword "^(spawn|race|sync|rush|branch|block|defer|option|loop|using|map|array|profile|not)$"))

; Conditional macros
(macro_call
  macro: (identifier) @keyword.conditional
  (#match? @keyword.conditional "^(if|then|else|case)$"))
(else_keyword) @keyword.conditional

; Loop macros
(macro_call
  macro: (identifier) @keyword.repeat
  (#match? @keyword.repeat "^(for|loop|do)$"))

; Any remaining macro call gets function.macro treatment (excludes keyword macros)
(macro_call
  macro: (identifier) @function.macro
  (#not-match? @function.macro "^(spawn|race|sync|rush|branch|block|defer|option|loop|using|map|array|profile|not|if|then|else|case|for|do|return|enum|module|class|interface|struct|tuple|type)$"))

; ---------------------------------------------------------------------------
; Statement keywords
; ---------------------------------------------------------------------------

[
  "set"
  "return"
  (continue_expression)
  (break_expression)
  (var_keyword)
] @keyword

; ---------------------------------------------------------------------------
; Operators
; ---------------------------------------------------------------------------

; Arithmetic / comparison / logic
(binary_expression
  operator: _ @operator)

(set_expression
  operator: _ @operator)

(unary_expression
  operator: _ @operator)

[
  "->"
  "=>"
  ".."
  "to"
  "where"
  ":"
  ":="
  "="
] @operator

; and/or/not/of override @operator — must come AFTER the operator patterns
[
  "and"
  "or"
  "not"
  "of"
] @keyword.operator

; ---------------------------------------------------------------------------
; Punctuation
; ---------------------------------------------------------------------------

[
  "{"
  "}"
  "("
  ")"
  "["
  "]"
  ":)"
] @punctuation.bracket

[
  ";"
  ","
  "."
  ". "
] @punctuation.delimiter

; ---------------------------------------------------------------------------
; Field access
; ---------------------------------------------------------------------------

(field_expression
  target: (identifier) @variable)
(field_expression
  field: (identifier) @variable.member)

; RHS bare identifiers (binary/unary exprs, plain args, etc.)
(binary_expression (identifier) @variable)
(unary_expression operand: (identifier) @variable)
(postfix_expression operand: (identifier) @variable)
(postfix_expression operator: "?" @operator)
(argument_list (identifier) @variable)
(argument_list (comma_separated_group (identifier) @variable))
(comma_separated_group (identifier) @variable)
(named_argument "?" @operator)
(named_argument (identifier) @variable)
; Named argument name overrides @variable above
(named_argument
  name: (identifier) @variable.parameter)

(declaration rhs: (identifier) @variable)

; Bare identifier as expression-statement directly in a block (e.g. option result)
(block (identifier) @variable)



; Optional type hint override: Foo : ?type — must come after @variable patterns
(declaration
  type_hint: (unary_expression
    operand: (identifier) @type))

; Type arguments inside parametric type hints — overrides @variable above
(declaration
  type_hint: (function_call
    arguments: (argument_list
      (identifier) @type
      (#set! "priority" 200))))

; Type arguments inside array-of-tuple type hints: []tuple(A, B)
(declaration
  type_hint: (array_container
    value: (function_call
      arguments: (argument_list
        (identifier) @type
        (#set! "priority" 200)))))

; RHS identifier on next line: Foo :=\n    Bar  (parsed as rhs: block (identifier))
(declaration
  rhs: (block
    (identifier) @variable))

; Class member declared as: SomeMacro. MemberName := value
; Parsed as: declaration lhs:(macro_call (block (identifier)))
(declaration
  lhs: (macro_call
    (block
      (identifier) @variable)))

; Supertype / interface in class(MySupertype) — must be LAST to override @variable
(declaration
  rhs: (macro_call
    macro: (identifier) @_kw
    (#match? @_kw "^(class|enum|interface|struct)$")
    arguments: (argument_list
      (identifier) @type
      (#set! "priority" 200))))

; Type alias rhs: Foo := tuple(A, B) — args are types, not variables
(declaration
  rhs: (block
    (function_call
      function: (identifier) @_fn
      (#eq? @_fn "tuple")
      arguments: (argument_list
        (identifier) @type
        (#set! "priority" 200)))))
