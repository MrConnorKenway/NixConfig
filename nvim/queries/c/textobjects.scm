(function_declarator
  declarator: (identifier) @function)

(function_declarator
  declarator: (parenthesized_declarator
    (pointer_declarator
      declarator: [
        (identifier) @function
        (field_identifier) @function
      ])))
