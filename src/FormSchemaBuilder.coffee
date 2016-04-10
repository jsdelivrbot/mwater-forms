
###
To pass isVisible, or other thing as prop to all questions, how much work:

28 places in 8 files! To use context or not to use context...

* switch form component to use response

===> evaluateExpr: (data, expr) ? Still requires data (which changes in rosters) but abstracts everythign else away. Context.
No schema necessary.



Could make indicator calculations in strict order? Painful to explain.

How to clean indicator calculations? Failed one could bork all of them that depend on it. Or not:

- Attempt to compile, skipping failed ICs
- Clean all exprs of all ICs, flagging error if different

What happens if column has a null JSONQL expression? E.g. blank indic calc?
 - doesn't even get added as column in the response schema! 
 - *** probably should so rest of calculations don't crash. it should be part of schema.

Cleaning an expression does not remove it entirely. But it might compile to null.



###

_ = require 'lodash'
formUtils = require '../src/formUtils'
ExprCompiler = require('mwater-expressions').ExprCompiler
update = require 'update-object'
ColumnNotFoundException = require('mwater-expressions').ColumnNotFoundException

# Append a string to each language
appendStr = (str, suffix) ->
  output = {}
  for key, value of str
    if key == "_base"
      output._base = value
    else
      # If it's a simple string
      if _.isString(suffix)
        output[key] = value + suffix
      else
        output[key] = value + (suffix[key] or suffix[suffix._base] or suffix.en)
  return output

# Map a tree that consists of items with optional 'contents' array. null means to discard item
mapTree = (tree, func) ->
  if not tree
    return tree

  if _.isArray(tree)
    return _.map(tree, (item) -> mapTree(item, func))

  # Map item
  output = func(tree)

  # Map contents
  if tree.contents
    output.contents = _.compact(_.map(tree.contents, (item) -> func(item)))

  return output

module.exports = class FormSchemaBuilder
  # Pass clone forms if a master form
  addForm: (schema, form, cloneForms) ->
    contents = []
    
    # Get deployments
    deploymentValues = _.map(form.deployments, (dep) -> { id: dep._id, name: { en: dep.name } })
    contents.push({ id: "deployment", type: "enum", name: { en: "Deployment" }, enumValues: deploymentValues })

    # Add user
    contents.push({ id: "user", type: "text", name: { en: "Enumerator" } })

    # Add code
    contents.push({ id: "code", type: "text", name: { en: "Response Code" } })

    # Add submitted on
    contents.push({ id: "submittedOn", type: "datetime", name: { en: "Submitted On" } })

    @addFormItem(form, form.design, contents)

    # Add to schema
    schema = schema.addTable({
      id: "responses:#{form._id}"
      name: form.design.name
      primaryKey: "_id"
      contents: contents
    })

    schema = @createIndicatorCalculationSections(schema, form, false)

    if form.isMaster
      schema = @addMasterForm(schema, form, cloneForms)

    # Create table
    return schema

  # Adds a table which references master form data from master_responses table
  addMasterForm: (schema, form, cloneForms) ->
    contents = []

    # Add user
    contents.push({ id: "user", type: "text", name: { en: "Enumerator" } })

    # Add submitted on
    contents.push({ id: "submittedOn", type: "datetime", name: { en: "Submitted On" } })

    # Add deployment enum values
    deploymentValues = _.map(form.deployments, (dep) -> { id: dep._id, name: { en: dep.name } })

    # Add all deployments from clones
    if cloneForms
      for cloneForm in cloneForms
        deploymentValues = deploymentValues.concat(
          _.map(cloneForm.deployments, (dep) -> { id: dep._id, name: appendStr(cloneForm.design.name, " - " + dep.name) })
          )

    contents.push({ id: "deployment", type: "enum", name: { en: "Deployment" }, enumValues: deploymentValues })

    # Add questions of form
    @addFormItem(form, form.design, contents)

    # Transform to reference master_responses flattened structure where all is stored as keys of data field
    contents = mapTree(contents, (item) =>
      switch item.type
        when "text", "date", "datetime", "enum"
          return update(item, jsonql: { $set: { type: "op", op: "->>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, item.id ]} })
        when "number" 
          return update(item, jsonql: { $set: { type: "op", op: "convert_to_decimal", exprs: [ { type: "op", op: "->>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, item.id ]} ] }})
        when "boolean" 
          return update(item, jsonql: { $set: { type: "op", op: "::boolean", exprs: [ { type: "op", op: "->>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, item.id ]} ] }})
        when "geometry"
          return update(item, jsonql: { $set: { type: "op", op: "::geometry", exprs: [ { type: "op", op: "->>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, item.id ]} ] }})
        when "join"
          return update(item, join: { 
            fromColumn: { $set: { type: "op", op: "->>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, item.id ] } }
            toColumn: { $set: "_id" }
          })

        else
          # Direct access to underlying JSON type
          return update(item, jsonql: { $set: { type: "op", op: "->", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, item.id ]}})
    )


    schema = schema.addTable({
      id: "master_responses:#{form._id}"
      name: appendStr(form.design.name, " (Master)")
      primaryKey: "response"
      contents: contents
    })

    schema = @createIndicatorCalculationSections(schema, form, true)

  # Create a section in schema called Indicators with one subsection for each indicator calculated
  createIndicatorCalculationSections: (schema, form, isMaster) ->
    tableId = if isMaster then "master_responses:#{form._id}" else "responses:#{form._id}"

    # Add indicator calculations
    if not form.indicatorCalculations or form.indicatorCalculations.length == 0
      return schema

    indicatorsSection = {
      type: "section"
      name: { _base: "en", en: "Indicators" }
      contents: []
    }

    # Re-add table
    schema = schema.addTable(update(schema.getTable(tableId), { contents: { $push: [indicatorsSection] } }))

    # Since the order to add indicator calculations is not clear (#1 might reference #2), we try again and again, handling ColumnNotFoundException gracefully
    todoIcs = form.indicatorCalculations.slice()      
    while todoIcs.length > 0
      successes = []
      lastError = null

      # For each indicator calculation todo
      for indicatorCalculation in todoIcs
        indicatorsSection = _.last(schema.getTable(tableId).contents)

        # Add to indicators section
        iscontents = indicatorsSection.contents.slice()
        try 
          iscontents.push(@createIndicatorCalculationSection(indicatorCalculation, schema, isMaster))
        catch err
          if err instanceof ColumnNotFoundException
            # Continue
            lastError = err
            continue
          throw err

        # Update in original
        contents = schema.getTable(tableId).contents.slice()
        contents[contents.length - 1] = update(indicatorsSection, { contents: { $set: iscontents } })

        # Re-add table
        schema = schema.addTable(update(schema.getTable(tableId), { contents: { $set: contents } }))
        successes.push(indicatorCalculation)

      if successes.length == 0
        # Rethrow error
        throw lastError

      # Remove successes
      todoIcs = _.difference(todoIcs, successes)

    return schema

  # Create a subsection of Indicators for an indicator calculation. Express in jsonql so that it can be computed direcly from the current response 
  # isMaster uses master_response as row to compute from
  createIndicatorCalculationSection: (indicatorCalculation, schema, isMaster) ->
    # Get indicator table
    indicTable = schema.getTable("indicator_values:#{indicatorCalculation.indicator}")

    # If not found, probably don't have permission
    if not indicTable
      return schema

    # Create compiler
    exprCompiler = new ExprCompiler(schema)

    # Map columns, replacing jsonql with compiled expression
    contents = _.compact(_.map(indicTable.contents, (item) ->
      return mapTree(item, (col) ->
        # Sections are passed through
        if col.type == "section"
          return col

        # Ignore if no expression
        expression = indicatorCalculation.expressions[col.id]
        if not expression
          return null

        # If master, hack expression to be from master_responses, not responses
        if isMaster
          expression = JSON.parse(JSON.stringify(expression).replace(/table":"responses:/g, "table\":\"master_responses:"))

        # Joins are special. Only handle "n-1" joins (which are from id fields in original indicator properties)
        if col.type == "join"
          if col.join.type != "n-1"
            return null

          # Compile to an jsonql of the id of the "to" table
          fromColumn = exprCompiler.compileExpr(expr: expression, tableAlias: "{alias}")

          # Create a join expression
          toColumn = schema.getTable(col.join.toTable).primaryKey

          col = update(col, { id: { $set: "indicator_calculation:#{indicatorCalculation._id}:#{col.id}" }, join: { 
            fromColumn: { $set: fromColumn }
            toColumn: { $set: toColumn }
            }})
          return col

        # Compile jsonql
        jsonql = exprCompiler.compileExpr(expr: expression, tableAlias: "{alias}")

        # Set jsonql and id
        col = update(col, { id: { $set: "indicator_calculation:#{indicatorCalculation._id}:#{col.id}" }, jsonql: { $set: jsonql }})
        return col
        )
      )
    )

    # Create section
    section = {
      type: "section"
      name: schema.getTable("indicator_values:#{indicatorCalculation.indicator}").name
      contents: contents
    }

    return section

  addFormItem: (form, item, contents) ->
    addColumn = (column) =>
      contents.push(column)

    # Add sub-items
    if item.contents
      if item._type == "Form"
        for subitem in item.contents
          @addFormItem(form, subitem, contents)

      else if item._type == "Section"        
        # Create section contents
        sectionContents = []
        for subitem in item.contents
          @addFormItem(form, subitem, sectionContents)
        contents.push({ type: "section", name: item.name, contents: sectionContents })

    else if formUtils.isQuestion(item)
      # Get type of answer
      answerType = formUtils.getAnswerType(item)
      switch answerType
        when "text"
          # Get a simple text column
          column = {
            id: "data:#{item._id}:value"
            type: "text"
            name: item.text
            jsonql: {
              type: "op"
              op: "#>>"
              exprs: [
                { type: "field", tableAlias: "{alias}", column: "data" }
                "{#{item._id},value}"
              ]
            }
          }
          addColumn(column)

        when "number"
          # Get a decimal column always as integer can run out of room
          column = {
            id: "data:#{item._id}:value"
            type: "number"
            name: item.text
            jsonql: {
              type: "op"
              op: "convert_to_decimal"
              exprs: [
                {
                  type: "op"
                  op: "#>>"
                  exprs: [
                    { type: "field", tableAlias: "{alias}", column: "data" }
                    "{#{item._id},value}"
                  ]
                }
              ]
            }
          }
          addColumn(column)

        when "choice"
          # Get a simple text column
          column = {
            id: "data:#{item._id}:value"
            type: "enum"
            name: item.text
            enumValues: _.map(item.choices, (c) -> { id: c.id, name: c.label })
            jsonql: {
              type: "op"
              op: "#>>"
              exprs: [
                { type: "field", tableAlias: "{alias}", column: "data" }
                "{#{item._id},value}"
              ]
            }
          }
          addColumn(column)

        when "choices"
          column = {
            id: "data:#{item._id}:value"
            type: "enumset"
            name: item.text
            enumValues: _.map(item.choices, (c) -> { id: c.id, name: c.label })
            jsonql: {
              type: "op"
              op: "#>"
              exprs: [
                { type: "field", tableAlias: "{alias}", column: "data" }
                "{#{item._id},value}"
              ]
            }
          }
          addColumn(column)

        when "date"
          # If date-time
          if item.format.match /ss|LLL|lll|m|h|H/
            # Fill in month and year and remove timestamp
            column = {
              id: "data:#{item._id}:value"
              type: "datetime"
              name: item.text
              jsonql: {
                type: "op"
                op: "#>>"
                exprs: [
                  { type: "field", tableAlias: "{alias}", column: "data" }
                  "{#{item._id},value}"
                ]
              }
            }
            addColumn(column)
          else
            # Fill in month and year and remove timestamp
            column = {
              id: "data:#{item._id}:value"
              type: "date"
              name: item.text
              # substr(rpad(data#>>'{questionid,value}',10, '-01-01'), 1, 10)
              jsonql: {
                type: "op"
                op: "substr"
                exprs: [
                  {
                    type: "op"
                    op: "rpad"
                    exprs:[
                      {
                        type: "op"
                        op: "#>>"
                        exprs: [
                          { type: "field", tableAlias: "{alias}", column: "data" }
                          "{#{item._id},value}"
                        ]
                      }
                      10
                      '-01-01'
                    ]
                  }
                  1
                  10
                ]
              }
            }
            addColumn(column)

        when "boolean"
          column = {
            id: "data:#{item._id}:value"
            type: "boolean"
            name: item.text
            jsonql: {
              type: "op"
              op: "::boolean"
              exprs: [
                {
                  type: "op"
                  op: "#>>"
                  exprs: [
                    { type: "field", tableAlias: "{alias}", column: "data" }
                    "{#{item._id},value}"
                  ]
                }
              ]
            }
          }

          addColumn(column)

        when "units"
          # Get a decimal column as integer can run out of room
          name = appendStr(item.text, " (magnitude)")

          column = {
            id: "data:#{item._id}:value:quantity"
            type: "number"
            name: name
            jsonql: {
              type: "op"
              op: "::decimal"
              exprs: [
                {
                  type: "op"
                  op: "#>>"
                  exprs: [
                    { type: "field", tableAlias: "{alias}", column: "data" }
                    "{#{item._id},value,quantity}"
                  ]
                }
              ]
            }
          }
          addColumn(column)

          column = {
            id: "data:#{item._id}:value:units"
            type: "enum"
            name: appendStr(item.text, " (units)")
            jsonql: {
              type: "op"
              op: "#>>"
              exprs: [
                { type: "field", tableAlias: "{alias}", column: "data" }
                "{#{item._id},value,units}"
              ]
            }
            enumValues: _.map(item.units, (c) -> { id: c.id, name: c.label })
          }
          addColumn(column)

        when "location"
          column = {
            id: "data:#{item._id}:value"
            type: "geometry"
            name: item.text
            # ST_SetSRID(ST_MakePoint(data#>>'{questionid,value,longitude}'::decimal, data#>>'{questionid,value,latitude}'::decimal),4326)
            jsonql: {
              type: "op"
              op: "ST_SetSRID"
              exprs: [
                {
                  type: "op"
                  op: "ST_MakePoint"
                  exprs: [
                    {
                      type: "op"
                      op: "::decimal"
                      exprs: [
                        { type: "op", op: "#>>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, "{#{item._id},value,longitude}"] }
                      ]
                    }
                    {
                      type: "op"
                      op: "::decimal"
                      exprs: [
                        { type: "op", op: "#>>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, "{#{item._id},value,latitude}"] }
                      ]
                    }
                  ]
                }
                4326
              ]
            }
          }
          
          addColumn(column)

          column = {
            id: "data:#{item._id}:value:accuracy"
            type: "number"
            name: appendStr(item.text, " (accuracy)")
            # data#>>'{questionid,value,accuracy}'::decimal
            jsonql: {
              type: "op"
              op: "::decimal"
              exprs: [
                { type: "op", op: "#>>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, "{#{item._id},value,accuracy}"] }
              ]
            }
          }
          
          addColumn(column)

          column = {
            id: "data:#{item._id}:value:altitude"
            type: "number"
            name: appendStr(item.text, " (altitude)")
            # data#>>'{questionid,value,accuracy}'::decimal
            jsonql: {
              type: "op"
              op: "::decimal"
              exprs: [
                { type: "op", op: "#>>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, "{#{item._id},value,altitude}"] }
              ]
            }
          }
          
          addColumn(column)

        when "site"
          # Legacy codes are stored under value directly, and newer ones under value: { code: "somecode" }
          codeExpr = {
            type: "op"
            op: "coalesce"
            exprs: [
              {
                type: "op"
                op: "#>>"
                exprs: [
                  { type: "field", tableAlias: "{alias}", column: "data" }
                  "{#{item._id},value,code}"
                ]
              }
              {
                type: "op"
                op: "#>>"
                exprs: [
                  { type: "field", tableAlias: "{alias}", column: "data" }
                  "{#{item._id},value}"
                ]
              }
            ]
          }

          column = {
            id: "data:#{item._id}:value"
            type: "join"
            name: item.text
            join: {
              type: "n-1"
              toTable: if item.siteTypes then "entities." + _.first(item.siteTypes).toLowerCase().replace(" ", "_") else "entities.water_point"
              fromColumn: codeExpr
              toColumn: "code"
            }
          }

          addColumn(column)

        when "entity"
          column = {
            id: "data:#{item._id}:value"
            type: "join"
            name: item.text
            join: {
              type: "n-1"
              toTable: "entities.#{item.entityType}"
              fromColumn: {
                type: "op"
                op: "#>>"
                exprs: [
                  { type: "field", tableAlias: "{alias}", column: "data" }
                  "{#{item._id},value}"
                ]
              }
              toColumn: "_id"
            }
          }

          addColumn(column)

        when "texts"
          # Get image
          column = {
            id: "data:#{item._id}:value"
            type: "text[]"
            name: item.text
            jsonql: {
              type: "op"
              op: "#>>"
              exprs: [
                { type: "field", tableAlias: "{alias}", column: "data" }
                "{#{item._id},value}"
              ]
            }
          }
          addColumn(column)

        when "image"
          # Get image
          column = {
            id: "data:#{item._id}:value"
            type: "image"
            name: item.text
            jsonql: {
              type: "op"
              op: "#>>"
              exprs: [
                { type: "field", tableAlias: "{alias}", column: "data" }
                "{#{item._id},value}"
              ]
            }
          }
          addColumn(column)

        when "images"
          # Get images
          column = {
            id: "data:#{item._id}:value"
            type: "imagelist"
            name: item.text
            jsonql: {
              type: "op"
              op: "#>>"
              exprs: [
                { type: "field", tableAlias: "{alias}", column: "data" }
                "{#{item._id},value}"
              ]
            }
          }
          addColumn(column)

      # Add specify
      if answerType in ['choice', 'choices']
        for choice in item.choices
          if choice.specify
            column = {
              id: "data:#{item._id}:specify:#{choice.id}"
              type: "text"
              name: appendStr(appendStr(appendStr(item.text, " ("), choice.label), ")")
              jsonql: {
                type: "op"
                op: "#>>"
                exprs: [
                  { type: "field", tableAlias: "{alias}", column: "data" }
                  "{#{item._id},specify,#{choice.id}}"
                ]
              }
            }
            addColumn(column)

      # Add comments
      if item.commentsField
        column = {
          id: "data:#{item._id}:comments"
          type: "text"
          name: appendStr(item.text, " (Comments)")
          jsonql: { type: "op", op: "#>>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, "{#{item._id},comments}"] }
        }

        addColumn(column)

      # Add timestamp
      if item.recordTimestamp
        column = {
          id: "data:#{item._id}:timestamp"
          type: "datetime"
          name: appendStr(item.text, " (Time Answered)")
          jsonql: { type: "op", op: "#>>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, "{#{item._id},timestamp}"] }
        }

        addColumn(column)

      # Add GPS stamp
      if item.recordLocation
        column = {
          id: "data:#{item._id}:location"
          type: "geometry"
          name: appendStr(item.text, " (Location Answered)")
          # ST_SetSRID(ST_MakePoint(data#>>'{questionid,value,longitude}'::decimal, data#>>'{questionid,value,latitude}'::decimal),4326)
          jsonql: {
            type: "op"
            op: "ST_SetSRID"
            exprs: [
              {
                type: "op"
                op: "ST_MakePoint"
                exprs: [
                  {
                    type: "op"
                    op: "::decimal"
                    exprs: [
                      { type: "op", op: "#>>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, "{#{item._id},location,longitude}"] }
                    ]
                  }
                  {
                    type: "op"
                    op: "::decimal"
                    exprs: [
                      { type: "op", op: "#>>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, "{#{item._id},location,latitude}"] }
                    ]
                  }
                ]
              }
              4326
            ]
          }
        }

        addColumn(column)

        column = {
          id: "data:#{item._id}:location:accuracy"
          type: "number"
          name: appendStr(item.text, " (Location Answered - accuracy)")
          # data#>>'{questionid,location,accuracy}'::decimal
          jsonql: {
            type: "op"
            op: "::decimal"
            exprs: [
              { type: "op", op: "#>>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, "{#{item._id},location,accuracy}"] }
            ]
          }
        }
        
        addColumn(column)

        column = {
          id: "data:#{item._id}:location:altitude"
          type: "number"
          name: appendStr(item.text, " (Location Answered - altitude)")
          # data#>>'{questionid,location,accuracy}'::decimal
          jsonql: {
            type: "op"
            op: "::decimal"
            exprs: [
              { type: "op", op: "#>>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, "{#{item._id},location,altitude}"] }
            ]
          }
        }
        
        addColumn(column)

      # Add n/a
      if item.alternates and item.alternates.na
        column = {
          id: "data:#{item._id}:na"
          type: "boolean"
          name: appendStr(item.text, " (Not Applicable)")
          # data#>>'{questionid,alternate}' = 'na'
          jsonql: {
            type: "op"
            op: "="
            exprs: [
              { type: "op", op: "#>>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, "{#{item._id},alternate}"] }
              "na"
            ]
          }
        }
        
        addColumn(column)

      if item.alternates and item.alternates.dontknow
        column = {
          id: "data:#{item._id}:dontknow"
          type: "boolean"
          name: appendStr(item.text, " (Don't Know)")
          # data#>>'{questionid,alternate}' = 'dontknow'
          jsonql: {
            type: "op"
            op: "="
            exprs: [
              { type: "op", op: "#>>", exprs: [{ type: "field", tableAlias: "{alias}", column: "data" }, "{#{item._id},alternate}"] }
              "dontknow"
            ]
          }
        }
        
        addColumn(column)

