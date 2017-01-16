_ = require 'lodash'

# Builds schema for entities. Always add entities before forms
module.exports = class EntitySchemaBuilder  
  # Pass in:
  #   entityTypes: list of entity types objects
  # Returns updated schema
  addEntities: (schema, entityTypes) ->
    # Keep list of reverse join columns (one to many) to add later. table and column
    reverseJoins = []

    # For each entity type, finding reverse joins
    for entityType in entityTypes
      mapTree entityType.properties, (prop) =>
        if prop.type == "id" and prop.idTable.match(/^entities\./)
          entityCode = prop.idTable.split(".")[1]

          # Check that exists
          if not _.findWhere(entityTypes, code: entityCode)
            return

          reverseJoins.push({
            table: prop.idTable
            column: {
              id: "!entities.#{entityType.code}.#{prop.id}"
              name: entityType.name
              deprecated: prop.deprecated or entityType.deprecated
              type: "join"
              join: {
                type: "1-n"
                toTable: "entities.#{entityType.code}"
                fromColumn: "_id"
                toColumn: prop.id
              }
            }
          })

    # For each entity type
    for entityType in entityTypes
      # Get label column
      labelColumn = null

      # Add properties
      contents = mapTree(entityType.properties, (prop) =>
        prop = _.clone(prop)

        # Use unique code as label
        if prop.uniqueCode
          labelColumn = prop.id

        # Don't include roles
        delete prop.roles

        # Convert id to join
        if prop.type == "id"
          prop.type = "join"
          prop.join = {
            type: "n-1"
            toTable: prop.idTable
            fromColumn: prop.id
            toColumn: "_id"
          }
          delete prop.idTable

        # Pad date fields
        if prop.type == "date"
          # rpad(field ,10, '-01-01')
          prop.jsonql = {
            type: "op"
            op: "rpad"
            exprs:[
              {
                type: "field"
                tableAlias: "{alias}"
                column: prop.id
              }
              10
              '-01-01'
            ]
          }

        return prop
        )


      # Add extra columns
      contents.push({
        id: "_managed_by"
        name: { en: "Managed By" }
        desc: { en: "User or group that manages the data for the site"}
        type: "join"
        join: {
          type: "n-1"
          toTable: "subjects"
          fromColumn: "_managed_by"
          toColumn: "id"
        }
      })

      contents.push({
        id: "_created_by"
        name: { en: "Added by user" }
        type: "join"
        join: {
          type: "n-1"
          toTable: "users"
          fromColumn: "_created_by"
          toColumn: "_id"
        }
      })

      contents.push({
        id: "_created_on"
        name: { en: "Date added" }
        type: "datetime"
      })

      # Add datasets
      contents.push({
        id: "!datasets"
        name: "Datasets"
        type: "join"
        join: {
          type: "n-n"
          toTable: "datasets"
          jsonql: {
            type: "op"
            op: "exists"
            exprs: [
              { 
                type: "query"
                selects: [{ type: "select", expr: null, alias: "null_value"}]
                from: { type: "table", table: "dataset_members", alias: "members" }
                where: {
                  type: "op"
                  op: "and"
                  exprs: [
                    { type: "op", op: "=", exprs: [{ type: "field", tableAlias: "members", column: "entity_type" }, entityType.code] }
                    { type: "op", op: "=", exprs: [{ type: "field", tableAlias: "members", column: "entity_id" }, { type: "field", tableAlias: "{from}", column: "_id" }] }
                    { type: "op", op: "=", exprs: [{ type: "field", tableAlias: "members", column: "dataset" }, { type: "field", tableAlias: "{to}", column: "_id" }] }
                  ]
                }
              }
            ]
          }
        }
      })

      tableId = "entities.#{entityType.code}"

      # Add reverse join columns
      for rj in reverseJoins
        if rj.table == tableId
          contents.push(rj.column)  

      table = { 
        id: tableId
        name: entityType.name
        primaryKey: "_id"
        label: labelColumn
        contents: contents
      }

      # Legacy only
      if entityType.code == "water_point_functionality_report"
        table.ordering = "date"

      # Create table
      schema = schema.addTable(table)

    return schema

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
