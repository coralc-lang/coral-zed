; Outline / symbol tree for coral.

; ── Functions and methods ──
(function_declaration
  name: (identifier) @name) @item

(generic_function_declaration
  name: (identifier) @name) @item

(method_declaration
  name: (identifier) @name) @item

(constructor_declaration
  name: (identifier) @name) @item

; ── Aggregate type declarations ──
(struct_declaration
  name: (identifier) @name) @item

(variant_declaration
  name: (identifier) @name) @item

(union_declaration
  name: (identifier) @name) @item

(enum_declaration
  name: (identifier) @name) @item

(trait_declaration
  name: (identifier) @name) @item

(extend_declaration
  target: (_) @name) @item

(typedef_declaration
  name: (identifier) @name) @item

(distinct_declaration
  name: (identifier) @name) @item

; ── Constants and imports ──
(const_declaration
  name: (identifier) @name) @item

(variable_declaration
  name: (identifier) @name) @item

(mod_declaration
  name: (identifier) @name) @item

; ── Enum variants and variant members ──
(enum_variant
  name: (identifier) @name) @item

(variant_member
  name: (identifier) @name) @item
