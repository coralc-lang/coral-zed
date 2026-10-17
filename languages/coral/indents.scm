; Auto-indentation for coral.
;
; Two rules matter here:
;
; 1. Only brace-delimited containers open an indent level. The declaration
;    nodes that *contain* those braces (function_declaration,
;    struct_declaration, if_statement, …) must NOT also be captured, or the
;    body is indented twice.
;
; 2. Every range is anchored with @start / @end so the indent runs *between*
;    the braces. A bare `(block) @indent` spans the whole node including its
;    closing brace, which pads the `}` one level too deep — very visible with
;    Allman style, where `{` and `}` sit on their own lines.

(block
  "{" @start
  "}" @end) @indent

(struct_body
  "{" @start
  "}" @end) @indent

(variant_fields
  "{" @start
  "}" @end) @indent

(initializer_list
  "{" @start
  "}" @end) @indent

(struct_literal
  "{" @start
  "}" @end) @indent

(import_list
  "{" @start
  "}" @end) @indent

(flag_case
  "{" @start
  "}" @end) @indent

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
