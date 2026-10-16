; Auto-indentation for coral.
;
; Only brace-delimited containers open an indent level. The declaration
; nodes that *contain* those braces (function_declaration,
; struct_declaration, if_statement, …) must NOT be captured as well, or the
; body gets indented twice.
;
; Capturing the whole node means the range runs from the node's start to its
; end, so anything with a dedicated body node is captured via that body node;
; constructs whose braces sit inline use @start / @end instead.

[
  (block)
  (struct_body)
  (variant_fields)
  (initializer_list)
  (struct_literal)
  (import_list)
  (flag_case)
] @indent

(enum_declaration
  "{" @start
  "}" @end) @indent

(variant_declaration
  "{" @start
  "}" @end) @indent

(trait_declaration
  "{" @start
  "}" @end) @indent

(flag_declaration
  "{" @start
  "}" @end) @indent

(flag_type
  "{" @start
  "}" @end) @indent

; Sibling switch cases stay aligned with each other.
(switch_statement
  (case_clause)+ @outdent)
