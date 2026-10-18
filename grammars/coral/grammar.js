// Coral grammar for tree-sitter
//
// Written from `coral-docs/grammar.md`:
//   * `pub` (never `export`) is the only visibility modifier, optionally
//     followed by one of `extern("C")` / `static`.
//   * Declarations are type-first: `<Type> <name>(params) {}`, `Type name;`,
//     `Type name = expr;`, plus the keyword decls `struct variant union enum
//     trait extend const typedef distinct flag import mod`.
//   * Types are prefix-annotated (`const T`, `comptime T`, `any Trait`) and
//     postfix-decorated (`T*`, `T[N]`, `T[]`).
//   * `char` is the builtin 32-bit UTF-32 scalar.  `cchar` is *not* a keyword
//     or primitive: it is a `distinct` supplied by the stdlib, so it parses as
//     a plain named type like any other user type.
//   * Attributes are `#[[name]]` / `#[[name(args)]]` / `#[[a, b]]`; the `@`
//     spellings (`@assert`, `@compileError`, ...) are compile-time attributes
//     inside expressions and `comptime {}` blocks.

const INT_SUFFIX = '([uU][lL]{0,2}|[lL]{1,2}[uU]?)';

module.exports = grammar({
  name: 'coral',

  extras: $ => [/\s/, $.doc_comment, $.comment],

  word: $ => $.identifier,

  conflicts: $ => [
    // leading `<Type>` on a declaration: fn / var / method / ctor / field
    [$.generic_function_declaration, $.named_type],
    [$.generic_function_declaration, $.base_type],
    [$.generic_function_declaration, $._type],
    [$.generic_function_declaration, $.named_type, $._expression],
    [$.generic_function_declaration, $._expression],
    [$.generic_function_declaration, $.function_declaration],
    [$.method_declaration, $.field_declaration],
    [$.method_declaration, $.constructor_declaration],
    [$.constructor_declaration, $.variable_declaration],
    [$.const_type, $.const_declaration],
    [$.comptime_type, $.comptime_block],
    [$.generic_params, $.comparison_expression],
    [$.generic_params, $.binary_expression],
    [$.generic_params, $.function_declaration],
    [$.generic_params, $.struct_literal],
    [$.call_expression, $.function_type],
    [$.call_expression, $.generic_type],
    [$.named_type, $._expression],
    [$.base_type, $._expression],
    [$.primitive_type, $._expression],
    [$._type, $._expression],
    [$.tuple_type, $._expression],
    [$.generic_type, $._expression],
    [$.pointer_type, $._expression],
    [$.array_type, $._expression],
    [$.slice_type, $._expression],
    [$.const_type, $._expression],
    [$.comptime_type, $._expression],
    [$.any_type, $._expression],
    [$.function_type, $._expression],
    [$.qualified_type, $._expression],
    [$._type, $.call_expression],
    [$.pointer_type, $.binary_expression],
    [$.pointer_type, $.unary_expression],
    [$.pointer_type, $.comparison_expression],
    [$.pointer_type, $.generic_type],
    [$.array_type, $.index_expression],
    [$.slice_type, $.index_expression],
    [$.array_type, $.pointer_type],
    [$.any_type, $._expression],
    [$.any_type, $.comparison_expression],
    [$.struct_literal, $.block],
    [$.struct_literal, $.struct_body],
    [$.struct_literal, $.comptime_block],
    [$.array_literal, $.index_expression],
    [$.array_literal, $.slice_type],
    [$.if_statement, $.if_expression],
    [$.switch_statement, $.switch_expression],
    [$.for_statement, $.while_statement],
    [$.for_statement, $._expression],
    [$.pattern, $._expression],
    [$.variant_pattern, $.struct_literal],
    [$.pattern, $.variant_pattern],
    [$.pattern, $.path_pattern],
    [$.pattern, $.or_pattern],
    [$.extern_declaration, $.named_type],
    [$.cast_expression, $.generic_type],
    [$.cast_expression, $.base_type],
    [$.cast_expression, $._expression],
    [$.generic_type, $.base_type],
    [$.generic_type, $.named_type],
    [$.generic_type, $.qualified_type],
    [$._type, $.generic_type],
    [$.qualified_type, $.generic_type],
    [$.named_type, $.generic_type],
    [$.module_path, $.import_symbol],
    [$.module_path, $.import_list],
    [$.constructor_declaration, $.named_type],
    [$.constructor_declaration, $.base_type],
    [$.constructor_declaration, $._type],
    [$.constructor_declaration, $._expression],
    [$.const_declaration, $.const_type],
    [$.const_declaration, $.variable_declaration],
    [$.const_declaration, $.field_declaration],
    [$.const_declaration, $.method_declaration],
    [$.const_declaration, $.function_declaration],
    [$.const_declaration, $.named_type],
    [$.const_declaration, $.base_type],
    [$.const_declaration, $._type],
    [$.const_declaration, $._expression],
    [$.const_declaration, $.comptime_type],
    [$.const_declaration, $.const_type, $.named_type],
    [$.local_declaration, $.field_declaration],
    [$.local_declaration, $.declarator],
    [$.field_declaration, $.declarator],
    [$.method_declaration, $.declarator],
    [$.function_declaration, $.declarator],
    [$.local_declaration, $.method_declaration],
    [$.local_declaration, $.function_declaration],
    [$.local_declaration, $.variable_declaration],
    [$.local_declaration, $.constructor_declaration],
    [$.local_declaration, $.const_declaration],
    [$.local_declaration, $._expression],
    [$.local_declaration, $._for_init],
    [$._for_init, $.assignment_expression],
    [$._for_init, $._expression],
    [$.for_statement, $._expression],
    [$.for_statement, $.assignment_expression],
    [$._for_init, $._expression],
    [$.local_declaration, $.array_type],
    [$.field_declaration, $.variable_declaration],
    [$.field_declaration, $.function_declaration],
    [$.field_declaration, $.method_declaration],
    [$.variable_declaration, $.method_declaration],
    [$.variable_declaration, $.function_declaration],
    [$.variable_declaration, $.array_type],
    [$.field_declaration, $.array_type],
    [$.method_declaration, $.array_type],
    [$.parameter, $.array_type],
    [$.cast_expression, $.parenthesized_expression],
    [$.cast_expression, $.tuple_type],
    [$.cast_expression, $.tuple_expression],
    [$.cast_expression, $.call_expression],
    [$.named_type, $.c_string],
    [$.cast_expression, $.binary_expression],
    [$.postfix_expression, $.binary_expression],
    [$.postfix_expression, $.unary_expression],
    [$.builtin_expression, $.call_expression],
    [$.statement, $._expression, $.if_expression],
    [$.statement, $._expression, $.switch_expression],
    [$.statement, $._expression, $.block],
    [$.compile_attr_statement, $._expression],
    [$.compile_attr_statement, $.statement],
    [$.compile_attr_statement, $.expression_statement],
    [$.struct_field, $._expression],
    [$.struct_field, $.initializer_list],
    [$._expression, $.struct_field],
    [$.statement, $._expression],
    [$.statement, $.if_expression],
    [$.statement, $.switch_expression],
    [$._for_binding, $._expression],
    [$.identifier_pattern, $.variant_pattern],
    [$.identifier_pattern, $.named_type, $.variant_pattern],
    [$.type_pattern, $.identifier_pattern],
    [$.type_pattern, $.variant_pattern],
    [$.type_pattern, $.named_type],
    [$.type_pattern, $.pattern],
    [$.path_pattern, $.qualified_type],
    [$.type_pattern, $._expression],
    [$.type_pattern, $.identifier_pattern],
    [$.type_pattern, $.pattern],
    [$.path_pattern, $.qualified_type],
    [$.identifier_pattern, $.struct_literal],
    [$.identifier_pattern, $._expression],
    [$.struct_member, $._expression],
    [$.struct_member, $.statement],
    [$.case_clause, $._expression],
    [$.comptime_block, $._expression],
    [$._expression, $.if_expression],
    [$._expression, $.switch_expression],
    [$._expression, $.block],
  ],

  rules: {
    source_file: $ => repeat($.declaration),

    // ══════════════════════════════════════════════════════════════════
    // 1. Lexical
    // ══════════════════════════════════════════════════════════════════

    // `/// doc` -- documentation comment. Declared before `comment` and listed
    // first in `extras`, because `//` and `///` both match to end of line and
    // the tie is broken by order. Without this a doc comment is
    // indistinguishable from an ordinary one, so hover cannot surface it.
    doc_comment: $ => token(seq('///', /[^\n]*/)),

    // `// line` and `/* block */` (block comments are not nested).
    comment: $ => token(choice(
      seq('//', /[^\n]*/),
      seq('/*', /[^*]*\*+([^/*][^*]*\*+)*/, '/'),
    )),

    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,

    module_path: $ => prec.right(seq(
      $.identifier,
      repeat(seq('::', $.identifier)),
    )),

    // ══════════════════════════════════════════════════════════════════
    // 2. Attributes
    // ══════════════════════════════════════════════════════════════════

    // `#[[packed]]`, `#[[reorder, packed]]`, `#[[generate(Drop, Eq)]]`.
    attribute_declaration: $ => seq(
      '#[[',
      commaSepTrail($.attribute_item),
      ']]',
    ),

    attribute_item: $ => seq(
      field('name', $.identifier),
      optional($.arguments),
    ),

    // `@assert(cond)`, `@compileError(...)`, `@isFormatLiteral`,
    // `@assertOut(...)` — compile-time attributes. `@sizeof(T)` /
    // `@alignof(T)` take a *type*, so those arguments are expressions.
    compile_attr: $ => prec.right(20, seq(
      '@',
      field('name', $.identifier),
      // The argument may be a type (`@sizeof(u8*)`, `@alignof(T)`) or an
      // expression (`@assert(cond)`, `@isFormatLiteral`).
      optional(seq('(', commaSep(choice($._expression, $._type)), ')')),
    )),

    // ══════════════════════════════════════════════════════════════════
    // 3. Declarations
    // ══════════════════════════════════════════════════════════════════

    declaration: $ => seq(
      repeat($.attribute_declaration),
      $._declaration,
    ),

    _declaration: $ => choice(
      $.mod_declaration,
      $.import_declaration,
      $.struct_declaration,
      $.variant_declaration,
      $.union_declaration,
      $.enum_declaration,
      $.trait_declaration,
      $.extend_declaration,
      $.extern_declaration,
      $.const_declaration,
      $.typedef_declaration,
      $.distinct_declaration,
      $.flag_declaration,
      $.function_declaration,
      $.generic_function_declaration,
      $.variable_declaration,
      $.var_declaration,
      $.comptime_block,
    ),

    // `pub mod name = import path[:symbols];`
    mod_declaration: $ => seq(
      optional('pub'),
      'mod',
      field('name', $.identifier),
      '=',
      'import',
      // A `::` module path, or a quoted file path (`import "arena"`).
      field('source', choice($.module_path, $.string_literal)),
      optional($.import_list),
      optional(seq(':', $.import_list)),
      ';',
    ),

    // `import name { syms };`
    // `import mod::sub { syms };`
    // `import(lib) std::x { syms };`
    // `import(lib) std;`
    import_declaration: $ => seq(
      'import',
      optional(seq('(', field('lib', $.identifier), ')')),
      field('source', choice($.module_path, $.string_literal)),
      // `import m::{ a, b }` and `import std::x { syms }`
      optional(seq('::', $.import_list)),
      optional($.import_list),
      ';',
    ),

    import_list: $ => seq('{', commaSepTrail($.import_symbol), '}'),

    import_symbol: $ => choice(
      field('name', $.identifier),
      seq($.module_path, optional($.import_list)),
      // `mod::{ a, b }` — the decided nested form
      seq(field('name', $.identifier), '::', $.import_list),
      $.import_list,
    ),

    struct_declaration: $ => seq(
      optional('pub'),
      'struct',
      field('name', $.identifier),
      optional($.generic_params),
      $.struct_body,
    ),

    struct_body: $ => seq(
      '{',
      repeat(choice($.attribute_declaration, $.struct_member)),
      '}',
    ),

    // Match arms (`Variant { … } => { … }`) live in struct bodies, so a
    // statement is allowed — but a bare expression statement would let
    // `Foo::Bar* f()` parse as an expression, so only the shapes that
    // actually appear are listed.
    struct_member: $ => choice(
      $.field_declaration,
      $.method_declaration,
      $.constructor_declaration,
      $.comptime_block,
      $.case_clause,
    ),

    // Local declaration: `Type name = expr;` / `Type name;` /
    // `Type name[N];`, with C-style multiple declarators:
    // `u32 a = 0, b = 0;`  (each declarator may repeat the type).
    local_declaration: $ => seq(
      optional('volatile'),
      field('type', $._type),
      commaSep1($.declarator),
      ';',
    ),

    declarator: $ => seq(
      $._declarator_head,
      optional(seq('=', choice($._expression, $.initializer_list))),
    ),

    _declarator_head: $ => seq(
      // `pub u8 const tab = …` puts the const marker after the type.
      optional(field('const', 'const')),
      field('name', $.identifier),
      optional($._array_declarator),
    ),

    // Fields: `Type name;` / `Type name[N];` (const-size declarators).
    field_declaration: $ => seq(
      optional('pub'),
      optional('volatile'),
      field('type', $._type),
      commaSep1($.declarator),
      ';',
    ),

    // Methods: `Type name(params) const? { … }` — the receiver is implicit.
    method_declaration: $ => seq(
      optional('static'),
      optional('pub'),
      optional('volatile'),
      $._typed_decl_head,
      optional($.generic_params),
      $.parameters,
      optional('const'),
      choice($.block, ';'),
    ),

    // Shared head of every "type-first" declaration, so that the
    // type / name / `[N]` / init / params decision is a single LR choice.
    _typed_decl_head: $ => seq(
      field('type', $._type),
      $._declarator_head,
    ),

    // `[N]` / `[N][M]` declarator suffix: `u8 tmp[72];`
    // An empty `[]` is a slice of unknown length: `static X86Reg t[] = { … };`
    _array_declarator: $ => repeat1(choice(
      seq('[', $._expression, ']'),
      seq('[', ']'),
    )),

    // Constructors: `static new(...)`, `static map(...)`.
    constructor_declaration: $ => seq(
      'static',
      field('name', $.identifier),
      $.parameters,
      choice($.block, ';'),
    ),

    // `variant Name<T> { VariantName { Type field; }, UnitName, … }`
    variant_declaration: $ => seq(
      optional('pub'),
      'variant',
      field('name', $.identifier),
      optional($.generic_params),
      '{',
      commaSepTrail($.variant_member),
      optional(','),
      '}',
    ),

    variant_member: $ => choice(
      seq(field('name', $.identifier), $.variant_fields),
      seq(field('name', $.identifier)),
    ),

    variant_fields: $ => seq('{', repeat($.field_declaration), '}'),

    union_declaration: $ => seq(
      optional('pub'),
      'union',
      field('name', $.identifier),
      optional($.generic_params),
      $.struct_body,
    ),

    // `enum Name { A, B = 1 }`
    enum_declaration: $ => seq(
      optional('pub'),
      'enum',
      field('name', $.identifier),
      optional($.generic_params),
      '{',
      commaSepTrail($.enum_variant),
      optional(','),
      '}',
    ),

    enum_variant: $ => seq(
      field('name', $.identifier),
      optional(seq('=', $._expression)),
    ),

    // `trait Name { fn(inline list of methods); }`
    trait_declaration: $ => seq(
      optional('pub'),
      'trait',
      field('name', $.identifier),
      optional($.generic_params),
      '{',
      repeat(choice($.attribute_declaration, $.trait_method)),
      '}',
    ),

    trait_method: $ => seq(
      optional('static'),
      field('return', $._type),
      field('name', $.identifier),
      optional($.generic_params),
      $.parameters,
      optional('const'),
      ';',
    ),

    // `pub extend<T> Name<T> { … }` and `extend S : Trait { … }`
    extend_declaration: $ => seq(
      optional('pub'),
      'extend',
      optional($.generic_params),
      field('target', $._extend_target),
      optional(seq(':', field('trait', choice($._extend_target, $.compile_attr)))),
      $.struct_body,
    ),

    _extend_target: $ => choice(
      $.primitive_type,
      $.named_type,
      $.qualified_type,
      $.generic_type,
    ),

    // `pub extern[c] Name;` → extern variable.
    // `extern("C") Type name(params);` / `extern name();`
    extern_declaration: $ => seq(
      optional('pub'),
      'extern',
      // The ABI tag is one token. It must beat the `(` that could start a
      // parameter list and the `"C"` string_literal would otherwise claim, so
      // it is a token() with high lexical precedence.
      optional(choice(
        token(prec(10, /\(\s*"[Cc]"\s*\)/)),
        token(prec(10, /\(\s*[Cc]\s*\)/)),
        token(prec(10, /\[\s*[Cc]\s*\]/)),
        token(prec(10, /\[\s*"[Cc]"\s*\]/)),
      )),
      choice(
        // `extern fn name(params);`  /  `extern name;` (foreign variable)
        seq(
          optional(field('return', $._type)),
          field('name', $.identifier),
          optional($.generic_params),
          optional($.parameters),
          optional('const'),
          choice($.block, ';'),
        ),
        // `extern fn name = ptr;` — a foreign alias bound to a symbol
        seq(
          field('type', $._type),
          field('name', $.identifier),
          '=',
          $._expression,
          ';',
        ),
      ),
    ),

    // `const Type name = expr;` — the type may be omitted when it is
    // deduced from the initialiser (`pub const INT64_MIN = -1;`).
    const_declaration: $ => seq(
      optional('pub'),
      'const',
      optional(field('type', $._type)),
      field('name', $.identifier),
      optional($._array_declarator),
      '=',
      choice($._expression, $.initializer_list),
      ';',
    ),

    // `pub typedef Name = Type;`
    typedef_declaration: $ => seq(
      optional('pub'),
      'typedef',
      field('name', $.identifier),
      '=',
      field('type', $._type),
      ';',
    ),

    // `pub distinct Name = Type;`
    distinct_declaration: $ => seq(
      optional('pub'),
      'distinct',
      field('name', $.identifier),
      '=',
      field('type', $._type),
      ';',
    ),

    flag_declaration: $ => seq(
      optional('pub'),
      'flag',
      '(',
      field('name', $.identifier),
      ')',
      '{',
      commaSepTrail($.flag_value),
      optional(','),
      '}',
    ),

    flag_value: $ => seq(
      field('name', $.identifier),
      optional(seq('=', $._expression)),
    ),

    // `<Type> <name><gen>(params) const? { body } | ;`
    function_declaration: $ => seq(
      optional('pub'),
      optional('static'),
      optional('volatile'),
      $._typed_decl_head,
      optional($.generic_params),
      $.parameters,
      optional('const'),
      choice($.block, ';'),
    ),

    // `print<comptime T>(T fmt, …)` — the return type is omitted and is
    // deduced from the function's `comptime { … }` block.
    generic_function_declaration: $ => seq(
      optional('pub'),
      optional('static'),
      field('name', $.identifier),
      field('generic', $.generic_params),
      $.parameters,
      optional('const'),
      choice($.block, ';'),
    ),

    // Top-level `Type name = expr;` (the initialiser is optional, so a
    // bare `Type name;` declaration parses too).
    variable_declaration: $ => seq(
      optional('pub'),
      optional('static'),
      optional('volatile'),
      $._typed_decl_head,
      optional(seq('=', choice($._expression, $.initializer_list))),
      ';',
    ),

    // `{ expr, expr, … }` — brace initialiser for arrays/structs.
    initializer_list: $ => seq(
      '{',
      commaSepTrail(choice($._expression, $.struct_field, $.initializer_list)),
      optional(','),
      '}',
    ),

    // `var name = expr;` — exists to drive type inference.
    var_declaration: $ => seq(
      optional('pub'),
      'var',
      field('name', $.identifier),
      '=',
      $._expression,
      ';',
    ),

    generic_params: $ => seq(
      choice('!<', '<'),
      commaSepTrail($.generic_param),
      optional(','),
      '>',
    ),

    generic_param: $ => seq(
      optional('comptime'),
      $.identifier,
      optional(seq(':', $._type)),
    ),

    // ══════════════════════════════════════════════════════════════════
    // 4. Types
    // ══════════════════════════════════════════════════════════════════

    _type: $ => choice(
      $.const_type,
      $.comptime_type,
      $.any_type,
      $.flag_type,
      $.function_type,
      $.pointer_type,
      $.array_type,
      $.slice_type,
      $.generic_type,
      $.qualified_type,
      $.tuple_type,
      $.base_type,
    ),

    base_type: $ => choice(
      $.primitive_type,
      $.named_type,
    ),

    // `const T` → Const(T)
    const_type: $ => prec.right(3, seq('const', $._type)),

    // `comptime T` → ComptimeT
    comptime_type: $ => prec.right(seq('comptime', $._type)),

    // `any Trait` — dyn-trait object type (decided syntax).
    any_type: $ => prec.right(seq(
      'any',
      optional('<'),
      $._type,
      optional('>'),
    )),

    // `void(u64)`, `u32(rawptr)`, `bool(T, T)` — the (optional) declared
    // name of a fn pointer comes from the enclosing field/param, e.g.
    // `usize(K) hf` is `parameter(function_type(usize, (K)), hf)`.
    function_type: $ => prec.right(seq(
      field('return', $._type),
      $.parameters,
    )),

    pointer_type: $ => prec.right(12, seq($._type, '*')),

    // `T[N]` → array
    array_type: $ => prec.right(seq(
      $._type,
      '[',
      $._expression,
      ']',
    )),

    // `T[]` → slice
    slice_type: $ => prec.right(seq(
      $._type,
      '[',
      ']',
    )),

    // `(T)` / `(T, U)` tuple
    tuple_type: $ => choice(
      prec.right(seq(
        '(',
        commaSepTrail($._type),
        optional(','),
        ')',
      )),
      // `struct(u32, u32)` — the named tuple spelling
      prec.right(seq(
        'struct',
        '(',
        commaSepTrail($._type),
        optional(','),
        ')',
      )),
    ),

    named_type: $ => choice(
      $.identifier,
      // `self` is usable in type position: `const T* f(const self*)`.
      'self',
    ),

    // `flag(arch) { … }` — a comptime-selected type, used by `distinct`.
    flag_type: $ => prec.right(seq(
      'flag',
      optional('('),
      field('flag', $.identifier),
      optional(')'),
      '{',
      commaSepTrail($.flag_case),
      optional(','),
      '}',
    )),

    flag_case: $ => seq(
      $.identifier,
      optional('::'),
      '=>',
      '{',
      commaSepTrail($._type),
      optional(','),
      '}',
    ),

    // `Option<T>`, `HashMap<K, V>`
    generic_type: $ => prec.right(seq(
      field('name', choice($.named_type, $.qualified_type)),
      choice('!<', '<'),
      commaSepTrail($._type),
      '>',
    )),

    // `mod::sub::Name`
    // prec 1 so a trailing `*` binds to the whole qualified type:
    // `Foo::Bar* f()` must be a function returning `Foo::Bar*`, not an
    // expression statement `Foo::Bar` followed by a call to `*`.
    qualified_type: $ => prec.right(1, seq(
      $.identifier,
      repeat1(seq('::', $.identifier)),
    )),

    // Keyword scalars only.  `char` is the builtin utf32 scalar; `cchar`
    // is a stdlib `distinct`, so it deliberately lives in named_type.
    primitive_type: $ => choice(
      'void', 'bool', 'char',
      'u8', 'u16', 'u32', 'u64', 'u128',
      'i8', 'i16', 'i32', 'i64', 'i128',
      'f32', 'f64',
      'usize', 'isize', 'rawptr', 'str',
    ),

    // ══════════════════════════════════════════════════════════════════
    // 5. Declarations' shared bits
    // ══════════════════════════════════════════════════════════════════

    parameters: $ => seq(
      '(',
      commaSep(choice($.parameter, $.variadic_parameter)),
      optional(','),
      ')',
    ),

    // `type name`, `type` (unnamed), and a bare `...` (variadic, last).
    parameter: $ => seq(
      field('type', $._type),
      optional(field('name', $.identifier)),
    ),

    // `...` may be named: `pub void vaprint(... args)`.
    variadic_parameter: $ => seq('...', optional(field('name', $.identifier))),

    // ══════════════════════════════════════════════════════════════════
    // 6. Statements
    // ══════════════════════════════════════════════════════════════════

    // Attributes are hoisted to the list level, mirroring `declaration`:
    // `#[[fallthrough]] switch (…)`, `#[[inline]] void g() {}`. Putting them
    // in a per-statement wrapper makes two adjacent attributes ambiguous.
    block: $ => seq('{', repeat(choice($.attribute_declaration, $.statement)), '}'),

    statement: $ => choice(
      $.local_declaration,
      $.var_declaration,
      $.const_declaration,
      $.flag_declaration,
      $.return_statement,
      $.if_statement,
      $.for_statement,
      $.while_statement,
      $.loop_statement,
      $.switch_statement,
      $.break_statement,
      $.continue_statement,
      $.defer_statement,
      $.asm_statement,
      $.comptime_block,
      $.compile_attr_statement,
      $.expression_statement,
      $.block,
    ),

    // `@assert(cond)`, `@compileError(…)` used as a statement prologue.
    compile_attr_statement: $ => prec.left(seq(
      $.compile_attr,
      $.statement,
    )),

    expression_statement: $ => seq($._expression, ';'),

    return_statement: $ => seq('return', optional($._expression), ';'),

    if_statement: $ => prec.right(seq(
      'if',
      '(',
      $._expression,
      ')',
      $.statement,
      optional(seq('else', $.statement)),
    )),

    // `for (init; cond; inc) { … }`
    // `for (const Type/var name : iterable) { … }`
    // `for (const type/var [ a, b ] : iterable) { … }`
    for_statement: $ => seq(
      'for',
      '(',
      choice(
        // C-style: `for (init; cond; inc) { … }`
        seq(
          optional($._for_init),
          ';',
          optional($._expression),
          ';',
          optional($._expression),
        ),
        // Range-based: `for (const Type/var name : iterable) { … }`
        seq(
          optional('const'),
          choice('var', $._type),
          $._for_binding,
          ':',
          $._expression,
        ),
      ),
      ')',
      $.statement,
    ),

    // A `for` init/inc clause — same as a declaration or assignment,
    // but without its own terminating `;`.
    _for_init: $ => choice(
      $.assignment_expression,
      seq(
        optional('volatile'),
        field('type', $._type),
        commaSep1($.declarator),
      ),
      $._expression,
    ),

    _for_binding: $ => choice(
      $.identifier,
      seq('[', commaSepTrail($.identifier), ']'),
    ),

    while_statement: $ => seq(
      'while',
      '(',
      $._expression,
      ')',
      $.statement,
    ),

    loop_statement: $ => seq('loop', $.statement),

    // `pattern => { body },` per case.  `else` is a pattern here, so a
    // trailing `else => { … }` acts as the catch-all case.
    switch_statement: $ => seq(
      'switch',
      '(',
      $._expression,
      ')',
      '{',
      repeat($.case_clause),
      '}',
    ),

    // A case may list several patterns:
    //   A::B,
    //   A::C => { … }
    // and its body may be an unbraced statement, in which case the comma
    // separator is what ends it.
    case_clause: $ => seq(
      commaSep1($.pattern),
      '=>',
      $.statement,
      optional(','),
    ),

    break_statement: $ => seq('break', optional(';')),

    continue_statement: $ => seq('continue', optional(';')),

    defer_statement: $ => seq('defer', $.statement),

    // `asm "…" { outputs }` (partially supported by the compiler).
    // `asm "tmpl" { … }`, `asm { … }`, `asm volatile { … }`, `asm volatile(…);`
    // `asm "tmpl" { outputs }`, `asm { … }`, `asm volatile { … }`,
    // `asm volatile(…);`
    //
    // The body is GCC extended-asm: template strings, then `:`-separated
    // operand / clobber sections. It used to be one opaque `/[^}]*/` token,
    // which highlighted as a blank span.
    asm_statement: $ => seq(
      'asm',
      optional('volatile'),
      choice(
        seq(
          '{',
          optional($.asm_template),
          repeat($.asm_section),
          '}',
        ),
        seq(
          '(', repeat($.string_literal), ')', ';',
        ),
      ),
    ),

    // `"movq %%rdi\n\t"` — the instruction template. Adjacent string
    // literals concatenate in extended asm; they are kept as separate
    // children rather than comma-separated because a comma would be
    // ambiguous with the section list that follows.
    asm_template: $ => repeat1(choice($.string_literal, $.raw_string)),

    // One `:`-introduced section: outputs, inputs, or clobbers.
    //   : "=a"(ret)
    //   : "0"(9u), "D"((usize)addr)
    //   : "rcx", "r8", "memory"
    asm_section: $ => seq(
      ':',
      commaSep(choice($._expression, $.asm_operand)),
    ),

    // A constraint pair: `"=a"(ret)` or `"memory"`.
    asm_operand: $ => seq(
      alias(token(/"[^"]*"/), $.asm_constraint),
      optional(seq('(', $._expression, ')')),
    ),

    // General compile-time block: selects / emits code.
    comptime_block: $ => prec.right(seq('comptime', $.block)),

    // `=, +=, -=, *=, /=, %=` are separate assign statements.
    // `=, +=, -=, *=, /=, %=` are separate assign expressions.
    assignment_expression: $ => prec.right(seq(
      field('left', $._expression),
      field('operator', choice(
        '=', '+=', '-=', '*=', '/=', '%=',
        '|=', '&=', '^=', '~=', '<<=', '>>=',
      )),
      field('right', $._expression),
    )),

    // ══════════════════════════════════════════════════════════════════
    // 7. Patterns
    // ══════════════════════════════════════════════════════════════════

    pattern: $ => choice(
      $.type_pattern,
      $.wildcard_pattern,
      $.literal_pattern,
      $.variant_pattern,
      $.tuple_pattern,
      $.or_pattern,
      $.path_pattern,
      $.else_pattern,
      $.identifier_pattern,
    ),

    // `cchar*`, `u8`, `T` — a type used as a type-switch label.
    type_pattern: $ => prec(2, $._type),

    wildcard_pattern: $ => '_',

    literal_pattern: $ => choice(
      $.number_literal,
      $.string_literal,
      $.raw_string,
      $.c_string,
      $.char_literal,
      $.boolean_literal,
      $.null_literal,
    ),

    // `Some { value }` / `Name { a, b }`
    variant_pattern: $ => seq(
      field('name', $.identifier),
      optional(seq(
        '{',
        commaSepTrail(choice($.identifier, $.wildcard_pattern)),
        '}',
      )),
    ),

    // `pat1 | pat2` (the decided `Or` form)
    or_pattern: $ => prec.left(seq($.pattern, '|', $.pattern)),

    path_pattern: $ => seq(
      $.identifier,
      repeat1(seq('::', $.identifier)),
    ),

    else_pattern: $ => 'else',

    identifier_pattern: $ => $.identifier,

    tuple_pattern: $ => seq(
      '(',
      commaSepTrail($.pattern),
      optional(','),
      ')',
    ),

    // ══════════════════════════════════════════════════════════════════
    // 8. Expressions
    // ══════════════════════════════════════════════════════════════════

    _expression: $ => choice(
      $.identifier,
      'self',
      $.number_literal,
      $.string_literal,
      $.raw_string,
      $.c_string,
      $.char_literal,
      $.boolean_literal,
      $.null_literal,
      $.compile_attr,
      $.builtin_expression,
      $.struct_literal,
      $.array_literal,
      $.tuple_expression,
      $.parenthesized_expression,
      $.conditional_expression,
      $.cast_expression,
      $.call_expression,
      $.field_expression,
      $.deref_field_expression,
      $.index_expression,
      $.generic_type,
      $.path_expression,
      $.postfix_expression,
      $.unary_expression,
      $.binary_expression,
      $.comparison_expression,
      $.assignment_expression,
      $.block,
      $.if_expression,
      $.switch_expression,
    ),

    boolean_literal: $ => choice('true', 'false'),
    null_literal: $ => 'null',

    number_literal: $ => token(choice(
      new RegExp(`0[xX][0-9a-fA-F][0-9a-fA-F_]*(${INT_SUFFIX})?`),
      new RegExp(`0[bB][01][01_]*(${INT_SUFFIX})?`),
      new RegExp(`0[oO][0-7][0-7_]*(${INT_SUFFIX})?`),
      new RegExp(`[0-9][0-9_]*\\.[0-9_]*([eE][+-]?[0-9][0-9_]*)?[fF]?`),
      new RegExp(`[0-9][0-9_]*[eE][+-]?[0-9][0-9_]*[fF]?`),
      new RegExp(`[0-9][0-9_]*(${INT_SUFFIX})?`),
    )),

    // Strings continue over newlines at the lex level; this grammar follows
    // the documented intent and terminates on the newline instead.
    string_literal: $ => token(seq(
      '"',
      repeat(choice(/[^\\"\n]/, /\\./)),
      '"',
    )),

    // `R"(…)"` / `R"<n>(…)"`
    raw_string: $ => token(seq(
      'R"',
      optional(/[A-Za-z0-9_]+/),
      '(',
      repeat(choice(/[^)"]+/, seq(')', /[^"]/))),
      ')',
      '"',
    )),

    // `C"…"` — C-style string: NUL-terminated, no length prefix.
    c_string: $ => token(seq(
      'C"',
      repeat(choice(/[^\\"\n]/, /\\./)),
      '"',
    )),

    char_literal: $ => token(seq(
      "'",
      choice(/[^\\'\n]/, /\\./),
      "'",
    )),

    // `sizeof`, `alignof`, `typeof`, `assert`, `assertOut`
    builtin_expression: $ => prec(20, seq(
      field('builtin', choice(
        'sizeof', 'alignof', 'typeof', 'assert', 'assertOut',
      )),
      '(',
      commaSepTrail(choice($._type, $._expression)),
      ')',
    )),

    // `commaSep` (not commaSepTrail) so `f()` is a call. An empty argument
    // list used to be reachable only as a function-pointer *type*, which made
    // `a();` parse as a declaration with a missing name. `...` forwards the
    // caller's variadic tail: `_printEmit(&out, fmt, ...)`.
    arguments: $ => seq(
      '(',
      commaSep(choice($._expression, $.variadic_forward)),
      optional(','),
      ')',
    ),

    variadic_forward: $ => '...',

    call_expression: $ => prec(21, seq(
      field('function', $._expression),
      $.arguments,
    )),

    // `.name` or, for tuples, `.0` / `.1`
    field_expression: $ => prec(22, seq(
      field('object', $._expression),
      '.',
      field('field', choice($.identifier, $.number_literal)),
    )),

    deref_field_expression: $ => prec(22, seq(
      field('object', $._expression),
      '->',
      field('field', $.identifier),
    )),

    index_expression: $ => prec(21, seq(
      field('object', $._expression),
      '[',
      field('index', $._expression),
      ']',
    )),

    // `ns::Item`, `ns::deep::Item`, `Color::Red`, `Type::Some {
    // .field = x }`
    path_expression: $ => prec(22, seq(
      choice($.identifier, $.generic_type),
      repeat1(seq('::', $.identifier)),
    )),

    // postfix `++` / `--`
    postfix_expression: $ => prec(23, seq(
      field('operand', $._expression),
      field('operator', choice('++', '--')),
    )),

    // `Name { .field = x }`, `Type::Some { .field = x }`, `Name<T> { … }`
    struct_literal: $ => prec(18, seq(
      field('name', choice($.identifier, $.generic_type, $.qualified_type,
                           $.path_expression)),
      '{',
      // Positional fields as well as `.name = value`: `_Buf { 1, buf, 0 }`
      // and `AsmRule { IrOpcode::And, "and", … }` both appear in the stdlib.
      optional(commaSepTrail(choice($.struct_field, $._expression))),
      optional(','),
      '}',
    )),

    struct_field: $ => prec(2, seq(
      optional('.'),
      field('name', $.identifier),
      '=',
      $._expression,
    )),

    array_literal: $ => seq(
      '[',
      commaSepTrail($._expression),
      optional(','),
      ']',
    ),

    tuple_expression: $ => prec(2, seq(
      '(',
      commaSepTrail($._expression),
      optional(','),
      ')',
    )),

    parenthesized_expression: $ => prec(3, seq(
      '(',
      $._expression,
      ')',
    )),

    // `a ? b : c`
    conditional_expression: $ => prec.right(1, seq(
      $._expression,
      '?',
      $._expression,
      ':',
      $._expression,
    )),

    // `x as T` (C-style) and `(T)x` (C-style type cast)
    cast_expression: $ => prec.right(choice(
      prec(15, seq(
        field('value', $._expression),
        'as',
        field('type', $._type),
      )),
      prec(15, seq(
        '(',
        field('type', $._type),
        ')',
        field('value', $._expression),
      )),
    )),

    unary_expression: $ => prec(13, seq(
      field('operator', choice('!', '~', '-', '&', '*', '++', '--')),
      field('operand', $._expression),
    )),

    binary_expression: $ => choice(
      prec.left(2, seq($._expression, '||', $._expression)),
      prec.left(3, seq($._expression, '&&', $._expression)),
      prec.left(4, seq($._expression, '|', $._expression)),
      prec.left(5, seq($._expression, '^', $._expression)),
      prec.left(6, seq($._expression, '&', $._expression)),
      prec.left(7, seq($._expression, choice('==', '!='), $._expression)),
      prec.left(9, seq($._expression, choice('<<', '>>'), $._expression)),
      prec.left(10, seq($._expression, choice('+', '-'), $._expression)),
      prec.left(11, seq($._expression, choice('*', '/', '%'), $._expression)),
    ),

    comparison_expression: $ => choice(
      prec.left(8, seq($._expression, '<', $._expression)),
      prec.left(8, seq($._expression, '<=', $._expression)),
      prec.left(8, seq($._expression, '>', $._expression)),
      prec.left(8, seq($._expression, '>=', $._expression)),
    ),

    if_expression: $ => seq(
      'if',
      '(',
      $._expression,
      ')',
      $.block,
      optional(seq('else', choice($.block, $.if_expression))),
    ),

    switch_expression: $ => seq(
      'switch',
      '(',
      $._expression,
      ')',
      '{',
      repeat($.case_clause),
      '}',
    ),
  },
});

// `rule` with at least one occurrence and no trailing comma.
function commaSep1(rule) {
  return seq(rule, repeat(seq(',', rule)));
}

// `rule` with no trailing comma, then an optional trailing comma.
function commaSep(rule) {
  return optional(seq(rule, repeat(seq(',', rule))));
}

// `rule` allowing a trailing comma (struct/enum/param/member lists).
function commaSepTrail(rule) {
  return seq(rule, repeat(seq(',', rule)), optional(','));
}
