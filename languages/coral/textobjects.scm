; Text objects for coral — used by vim mode's af/if/ac/ic motions.

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
(extend_declaration) @class.around

(comment)+ @comment.around
(comment) @comment.inside
