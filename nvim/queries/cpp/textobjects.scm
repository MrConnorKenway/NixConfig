(function_declarator
  declarator: (identifier) @function)

(function_declarator
  declarator: (field_identifier) @function)

(function_declarator
  declarator: (parenthesized_declarator
    (pointer_declarator
      declarator: (field_identifier) @function)))

(function_declarator
  declarator: (qualified_identifier
    name: (identifier) @function))
