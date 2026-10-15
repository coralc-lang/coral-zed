; Text objects for coral — `ai`-style selection.
; These use plain node patterns; `body` field names are not declared in
; grammar.js for cry.

(function_declaration) @function.around
(function_declaration (block) @function.inside)

(method_declaration) @function.around
(method_declaration (block) @function.inside)

(constructor_declaration) @function.around

(struct_declaration) @class.around
(struct_declaration (struct_body) @class.inside)

(variant_declaration) @class.around
(union_declaration) @class.around
(enum_declaration) @class.around
(trait_declaration) @class.around

(parameter
  (identifier) @parameter.inside) @parameter.around

(comment) @comment.around
(comment) @comment.inside
