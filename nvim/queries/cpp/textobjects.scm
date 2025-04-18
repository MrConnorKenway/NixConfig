(function_declarator
  declarator: [
    (identifier) @function
    (operator_name) @function
    (destructor_name (identifier) @function)
  ])

(function_declarator
  declarator: (field_identifier) @function)

(function_declarator
  declarator: (parenthesized_declarator
    (pointer_declarator
      declarator: (field_identifier) @function)))

(function_declarator
  declarator: [
    (qualified_identifier
      name: [
        (identifier) @function
        (operator_name) @function
        (destructor_name (identifier) @function)
      ])
    (qualified_identifier
      name: (qualified_identifier
        name: [
          (identifier) @function
          (operator_name) @function
          (destructor_name (identifier) @function)
        ]))
    (qualified_identifier
      name: (qualified_identifier
        name: (qualified_identifier
          name: [
             (identifier) @function
             (operator_name) @function
             (destructor_name (identifier) @function)
          ])))
    (qualified_identifier
      name: (qualified_identifier
        name: (qualified_identifier
          name: (qualified_identifier
            name: [
               (identifier) @function
               (operator_name) @function
               (destructor_name (identifier) @function)
            ]))))
    (qualified_identifier
      name: (qualified_identifier
        name: (qualified_identifier
          name: (qualified_identifier
            name: (qualified_identifier
              name: [
                 (identifier) @function
                 (operator_name) @function
                 (destructor_name (identifier) @function)
              ])))))
    (qualified_identifier
      name: (qualified_identifier
        name: (qualified_identifier
          name: (qualified_identifier
            name: (qualified_identifier
              name: (qualified_identifier
                name: [
                   (identifier) @function
                   (operator_name) @function
                   (destructor_name (identifier) @function)
                ]))))))
  ])
