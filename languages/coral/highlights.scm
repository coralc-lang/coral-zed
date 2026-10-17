; Coral highlights — matches grammars/coral/grammar.js
; Node names there: declaration / function_declaration /
; variable_declaration / const_declaration / struct_declaration /
; field_declaration / method_declaration / enum_declaration /
; variant_declaration / union_declaration / trait_declaration /
; extend_declaration / import_declaration / mod_declaration /
; typedef_declaration / distinct_declaration / extern_declaration /
; generic_params / parameters / parameter / pattern / switch_statement /
; case_clause / etc.

; ── Comments ──
(comment) @comment

; ── Attributes ──
; `#[[packed]]` / `#[[const, inline, hot]]` / `#[[generate(Drop, Eq)]]`
(attribute_declaration) @attribute
(attribute_item name: (identifier) @attribute)
; `@assert`, `@compileError`, `@isFormatLiteral`, `@assertOut`
(compile_attr) @attribute
(compile_attr name: (identifier) @attribute)
; ── Literals ──
; `C"…"` is a C string (NUL-terminated, no length prefix), so it gets its
; own scope instead of sharing @string with coral strings.
(string_literal) @string
(c_string) @string.special
(raw_string) @string
(char_literal) @character
(number_literal) @number
(boolean_literal) @constant.builtin
(null_literal) @constant.builtin

; ── Keywords ──
[
  "struct"
  "variant"
  "union"
  "enum"
  "trait"
  "extend"
  "flag"
] @keyword.declaration.type

[
  "import"
  "mod"
] @keyword.import

[
  "extern"
  "static"
  "const"
  "typedef"
  "distinct"
  "comptime"
  "volatile"
  "pub"
] @keyword.declaration

[
  "if"
  "else"
  "switch"
  "for"
  "while"
  "loop"
  "return"
  "break"
  "continue"
  "defer"
  "asm"
] @keyword.control

[
  "sizeof"
  "alignof"
  "typeof"
  "assert"
  "assertOut"
] @function.builtin

; `and` / `or` substitute words also read as control in coral
[
  "self"
  "as"
  "any"
  "var"
] @keyword.operator

; ── Types ──
; Primitive keyword scalars — `char` is the builtin utf32 scalar, not
; `cchar` (which is a stdlib `distinct` and so stays a named_type).
(primitive_type) @type.builtin

(const_type) @type
(comptime_type) @type
(slice_type) @type
(array_type) @type
(pointer_type) @type
(generic_type) @type
(generic_type name: (named_type) @type)
(generic_type name: (qualified_type) @type)
(function_type) @type
(any_type) @type
(flag_type) @type
(qualified_type) @type
(tuple_type) @type

; Named / struct types and their generic arguments
(named_type) @type
(base_type (named_type) @type)
(generic_type name: (qualified_type) @type)

; Generic type arguments: the `T` in `Option<T>`
(generic_type) @type
(generic_type (named_type) @type)
(generic_type (qualified_type) @type)

; `T` inside `struct Name<T>` — the type parameter position
(generic_param) @type.parameter
(generic_param (identifier) @type.parameter)

; struct / variant / enum / trait names
(struct_declaration name: (identifier) @type)
(variant_declaration name: (identifier) @type)
(union_declaration name: (identifier) @type)
(enum_declaration name: (identifier) @type)
(trait_declaration name: (identifier) @type)
(extend_declaration target: (_) @type)
(trait_declaration) @type ; method-less trait body
(enum_variant name: (identifier) @variant)

; ── Declarations ──
(function_declaration name: (identifier) @function)
(generic_function_declaration name: (identifier) @function)
(method_declaration name: (identifier) @method)
(constructor_declaration name: (identifier) @constructor)
(field_declaration (declarator name: (identifier) @property))
(variable_declaration name: (identifier) @variable)
(local_declaration (declarator name: (identifier) @variable))
(var_declaration name: (identifier) @variable)
(const_declaration name: (identifier) @constant)
(typedef_declaration name: (identifier) @type)
(distinct_declaration name: (identifier) @type)
(extern_declaration name: (identifier) @function)
(parameter name: (identifier) @variable.parameter)
(variadic_parameter) @variable.parameter
(import_declaration (identifier) @module)
(import_declaration (module_path) @module)
(import_symbol name: (identifier) @module)
(mod_declaration name: (identifier) @module)
(struct_field name: (identifier) @property)

; ── Patterns ──
; `Some { value }`, `_`, `a | b`
(pattern) @variant
(variant_pattern name: (identifier) @variant)
(variant_pattern (identifier) @property)
(identifier_pattern) @variable
(wildcard_pattern) @variable
(else_pattern) @keyword.control
(or_pattern) @variant

; ── Expressions ──
(call_expression function: (identifier) @function.call)
(call_expression function: (field_expression field: (identifier) @function.call))
(call_expression function: (path_expression) @function.call)
(builtin_expression builtin: _ @function.builtin)
(cast_expression type: (_) @type)
(struct_literal name: (identifier) @type)
(struct_literal name: (qualified_type) @type)
(field_expression field: (identifier) @property)
(deref_field_expression field: (identifier) @property)
(path_expression) @module
(unary_expression operator: _ @operator)
(postfix_expression operator: _ @operator)
(binary_expression) @operator
(assignment_expression operator: _ @operator)
(comparison_expression) @operator
(conditional_expression) @operator

; ── Operators ──
[
  "="
  "+="
  "-="
  "*="
  "/="
  "%="
  "|="
  "&="
  "^="
  "~="
  "<<="
  ">>="
  "++"
  "--"
  "->"
  "=>"
  "::"
  "..."
  "!"
  "~"
  "&"
  "|"
  "^"
  "+"
  "-"
  "*"
  "/"
  "%"
  "<"
  ">"
  "<="
  ">="
  "=="
  "!="
  "<<"
  ">>"
  "&&"
  "||"
  "?"
] @operator

; ── Punctuation ──
[
  "{"
  "}"
  "("
  ")"
  "["
  "]"
] @punctuation.bracket

[
  ","
  ";"
  "."
  ":"
] @punctuation.delimiter

; ── Attribute markers ──
[
  "#[["
  "]]"
  "@"
] @punctuation.special
