(function_declaration
  name: [
    (identifier) @function
    (dot_index_expression
      field: (identifier) @function)
    (method_index_expression
      method: (identifier) @function)
  ])

(function_definition
  !name) @function

(function_declaration
  !name) @function
