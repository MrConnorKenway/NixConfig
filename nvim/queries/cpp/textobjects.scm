(function_declarator
  declarator: [
    (identifier) @function
    (operator_name) @function
    (field_identifier) @function
    (destructor_name (identifier) @function)
    (parenthesized_declarator
        (pointer_declarator
          declarator: [
            (identifier) @function
            (field_identifier) @function
          ]))
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
