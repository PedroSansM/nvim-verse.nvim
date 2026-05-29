; Scope boundaries
(source_file) @local.scope
(block) @local.scope

; Definitions
(function_declaration
  name: (identifier) @local.definition.method)

(declaration
  lhs: (identifier) @local.definition)

(is_declaration
  lhs: (identifier) @local.definition)

(named_argument
  name: (identifier) @local.definition.parameter)

; References
(identifier) @local.reference
