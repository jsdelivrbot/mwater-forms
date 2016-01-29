_ = require 'lodash'
markdown = require("markdown").markdown
ezlocalize = require 'ez-localize'

formUtils = require './formUtils'
conditionUtils = require './conditionUtils'

TextQuestion = require './TextQuestion'
NumberQuestion = require './NumberQuestion'
RadioQuestion = require './RadioQuestion'
DropdownQuestion = require './DropdownQuestion'
MulticheckQuestion = require './MulticheckQuestion'
DateQuestion = require './DateQuestion'
UnitsQuestion = require './UnitsQuestion'
LocationQuestion = require './LocationQuestion'
ImageQuestion = require './ImageQuestion'
ImagesQuestion = require './ImagesQuestion'
CheckQuestion = require './CheckQuestion'
TextListQuestion = require './TextListQuestion'
SiteQuestion = require './SiteQuestion'
BarcodeQuestion = require './BarcodeQuestion'
EntityQuestion = require './EntityQuestion'
Instructions = require './Instructions'

Section = require './Section'
Sections = require './Sections'
FormView = require './FormView'
FormControls = require './FormControls'

FormEntityLinker = require './FormEntityLinker'

# Compiles from Form JSON to a form control. 
# Constructor must be passed:
# 'model': <Backbone.Model> to use for storing responses
# 'locale': optional locale to use (e.g. "en")
# 'ctx': context for forms. See docs/Forms Context.md
# Items returned do not need @render() called. The constructor does it automatically
module.exports = class FormCompiler
  constructor: (options) ->
    @model = options.model
    @locale = options.locale or "en"
    @ctx = options.ctx or {}

  # Creates a localizer for the form
  createLocalizer: (form) ->
    # Create localizer
    localizedStrings = form.localizedStrings or []
    localizerData = {
      locales: form.locales
      strings: localizedStrings
    }
    T = new ezlocalize.Localizer(localizerData, @locale).T
    return T

  compileString: (str) =>
    # If no base or null, return null
    if not str? or not str._base
      return null

    # Return for locale if present
    if str[@locale || "en"]
      return str[@locale || "en"]

    # Return base if present
    return str[str._base] || ""

  compileValidationMessage: (val) =>
    str = @compileString(val.message)
    if str
      return str
    return true

  compileValidation: (val) =>
    switch val.op 
      when "lengthRange"
        return (answer) =>
          value = if answer? and answer.value? then answer.value else ""
          len = value.length
          if val.rhs.literal.min? and len < val.rhs.literal.min
            return @compileValidationMessage(val)
          if val.rhs.literal.max? and len > val.rhs.literal.max
            return @compileValidationMessage(val)
          return null
      when "regex"
        return (answer) =>
          value = if answer? and answer.value? then answer.value else ""
          if value.match(val.rhs.literal)
            return null
          return @compileValidationMessage(val)
      when "range"
        return (answer) =>
          value = if answer? and answer.value? then answer.value else 0
          # For units question, get quantity
          if value.quantity?
            value = value.quantity
            
          if val.rhs.literal.min? and value < val.rhs.literal.min
            return @compileValidationMessage(val)
          if val.rhs.literal.max? and value > val.rhs.literal.max
            return @compileValidationMessage(val)
          return null
      else
        throw new Error("Unknown validation op " + val.op)

  compileValidations: (vals) =>
    compVals = _.map(vals, @compileValidation)
    return (answer) =>
      for compVal in compVals
        result = compVal(answer)
        if result
          return result

      return null

  compileChoice: (choice) =>
    return {
      id: choice.id
      label: @compileString(choice.label)
      hint: @compileString(choice.hint)
      specify: choice.specify
    }

  compileChoices: (choices) ->
    return _.map choices, @compileChoice

  compileCondition: (cond) =>
    getValue = =>
      answer = @model.get(cond.lhs.question) || {}
      return answer.value

    getAlternate = =>
      answer = @model.get(cond.lhs.question) || {}
      return answer.alternate

    switch cond.op
      when "present"
        return () =>
          value = getValue()
          return not(not value) and not (value instanceof Array and value.length == 0)
      when "!present"
        return () =>
          value = getValue()
          return (not value) or (value instanceof Array and value.length == 0)
      when "contains"
        return () =>
          return (getValue() or "").indexOf(cond.rhs.literal) != -1
      when "!contains"
        return () =>
          return (getValue() or "").indexOf(cond.rhs.literal) == -1
      when "="
        return () =>
          return getValue() == cond.rhs.literal
      when ">", "after"
        return () =>
          return getValue() > cond.rhs.literal
      when "<", "before"
        return () =>
          return getValue() < cond.rhs.literal
      when "!="
        return () =>
          return getValue() != cond.rhs.literal
      when "includes"
        return () =>
          return _.contains(getValue() or [], cond.rhs.literal) or cond.rhs.literal == getAlternate()
      when "!includes"
        return () =>
          return not _.contains(getValue() or [], cond.rhs.literal) and cond.rhs.literal != getAlternate()
      when "is"
        return () =>
          return getValue() == cond.rhs.literal or getAlternate() == cond.rhs.literal
      when "isnt"
        return () =>
          return getValue() != cond.rhs.literal and getAlternate() != cond.rhs.literal
      when "isoneof"
        return () =>
          value = getValue()
          if _.isArray(value)
            return _.intersection(cond.rhs.literal, value).length > 0 or _.contains(cond.rhs.literal, getAlternate()) 
          else
            return _.contains(cond.rhs.literal, value) or _.contains(cond.rhs.literal, getAlternate()) 
      when "isntoneof"
        return () =>
          value = getValue()
          if _.isArray(value)
            return _.intersection(cond.rhs.literal, value).length == 0 and not _.contains(cond.rhs.literal, getAlternate())
          else
            return not _.contains(cond.rhs.literal, value) and not _.contains(cond.rhs.literal, getAlternate())
      when "true"
        return () =>
          return getValue() == true
      when "false"
        return () =>
          return getValue() != true
      else
        throw new Error("Unknown condition op " + cond.op)

  compileConditions: (conds, form) =>
    # Only use valid conditions
    if form?
      conds = _.filter conds, (cond) -> conditionUtils.validateCondition(cond, form)
    compConds = _.map(conds, @compileCondition)
    return =>
      for compCond in compConds
        if not compCond()
          return false

      return true

  # Compile property links into a function that loads answers
  compileLoadLinkedAnswers: (propertyLinks) ->
    return (entity) =>
      if not propertyLinks
        return

      formEntityLinker = new FormEntityLinker(entity, @ctx.getProperty, @model)
      for propLink in propertyLinks
        formEntityLinker.loadToForm(propLink)

  # Compile property links into a function that saves linked values
  compileSaveLinkedAnswers: (propertyLinks, form) ->
    return () =>
      entity = {}

      if form
        isQuestionVisible = (questionId) =>
          question = formUtils.findItem(form, questionId)

          if not question
            console.log "Misconfigured entities question in form question #{questionId}"
            return false

          # Find which section question is in since section can make question invisible
          section = _.find(form.contents, (item) =>
            return item._type == "Section" and formUtils.findItem(item, questionId)
            )
          if section
            if not @compileConditions(section.conditions, form)()
              return false
          return @compileConditions(question.conditions, form)()
      else
        isQuestionVisible = null

      formEntityLinker = new FormEntityLinker(entity, @ctx.getProperty, @model, isQuestionVisible)

      for propLink in propertyLinks
        formEntityLinker.saveFromForm(propLink)

      return entity

  # Compile a question with the given form context
  compileQuestion: (q, T, form) =>
    T = T or ezlocalize.defaultT

    # Compile validations
    compiledValidations = @compileValidations(q.validations)

    options = {
      model: @model
      id: q._id
      required: q.required
      prompt: @compileString(q.text)
      code: q.code
      hint: @compileString(q.hint)
      help: if @compileString(q.help) then markdown.toHTML(@compileString(q.help))
      commentsField: q.commentsField
      recordTimestamp: q.recordTimestamp
      recordLocation: q.recordLocation
      sticky: q.sticky
      validate: =>
        # Get answer
        answer = @model.get(q._id)
        return compiledValidations(answer)
      conditional: if q.conditions and q.conditions.length > 0 then @compileConditions(q.conditions, form)
      ctx: @ctx
      T: T
    }
    
    # Add alternates
    if q.alternates 
      options.alternates = []
      if q.alternates.na
        options.alternates.push { id: "na", label: T("Not Applicable") } 
      if q.alternates.dontknow
        options.alternates.push { id: "dontknow", label: T("Don't Know") } 

    switch q._type
      when "TextQuestion"
        options.format = q.format
        return new TextQuestion(options)
      when "NumberQuestion"
        options.decimal = q.decimal
        return new NumberQuestion(options)
      when "RadioQuestion"
        options.choices = @compileChoices(q.choices)
        options.radioAlternates = true  # Use radio button
        return new RadioQuestion(options)
      when "DropdownQuestion"
        options.choices = @compileChoices(q.choices)
        return new DropdownQuestion(options)
      when "MulticheckQuestion"
        options.choices = @compileChoices(q.choices)
        return new MulticheckQuestion(options)
      when "DateQuestion"
        options.format = q.format
        return new DateQuestion(options)
      when "UnitsQuestion"
        options.decimal = q.decimal
        options.units = @compileChoices(q.units)
        options.defaultUnits = q.defaultUnits
        options.unitsPosition = q.unitsPosition
        return new UnitsQuestion(options)
      when "LocationQuestion"
        return new LocationQuestion(options)
      when "ImageQuestion"
        if q.consentPrompt
          options.consentPrompt = @compileString(q.consentPrompt)

        return new ImageQuestion(options)
      when "ImagesQuestion"
        if q.consentPrompt
          options.consentPrompt = @compileString(q.consentPrompt)

        return new ImagesQuestion(options)
      when "CheckQuestion"
        options.label = @compileString(q.label)
        return new CheckQuestion(options)
      when "TextListQuestion"
        return new TextListQuestion(options)
      when "SiteQuestion"
        options.siteTypes = q.siteTypes
        return new SiteQuestion(options)
      when "BarcodeQuestion"
        return new BarcodeQuestion(options)
      when "EntityQuestion"
        options.locale = @locale
        options.entityType = q.entityType
        options.entityFilter = q.entityFilter
        options.displayProperties = q.displayProperties
        options.selectionMode = q.selectionMode
        options.selectProperties = q.selectProperties
        options.mapProperty = q.mapProperty
        options.selectText = @compileString(q.selectText)
        options.loadLinkedAnswers = @compileLoadLinkedAnswers(q.propertyLinks)
        options.hidden = q.hidden
        return new EntityQuestion(options)

    throw new Error("Unknown question type")

  compileInstructions: (item, T, form) =>
    T = T or ezlocalize.defaultT

    options = {
      model: @model
      id: item._id
      html: if @compileString(item.text) then markdown.toHTML(@compileString(item.text))
      conditional: if item.conditions and item.conditions.length > 0 then @compileConditions(item.conditions, form)
      ctx: @ctx
      T: T
    }
    return new Instructions(options)

  compileItem: (item, T, form) =>
    if formUtils.isQuestion(item)
      return @compileQuestion(item, T, form)

    if item._type == "Instructions"
      return @compileInstructions(item, T, form)

    throw new Error("Unknown item type: " + item._type)

  compileSection: (section, T, form) =>
    T = T or ezlocalize.defaultT

    # Compile contents
    contents = _.map section.contents, (item) => @compileItem(item, T, form)

    options = {
      model: @model
      id: section._id
      ctx: @ctx
      T: T
      name: @compileString(section.name)
      contents: contents
      conditional: if section.conditions and section.conditions.length > 0 then @compileConditions(section.conditions, form)
    }

    return new Section(options)

  # Compiles a form. Options are:
  #  entityType: type of optional entity to preload
  #  entity: optional entity to preload into matching form question
  #  entityQuestionId: optional question to preload entity into. Will be inferred if not specified
  #  submitLabel: Label for submit button
  #  discardLabel: Label for discard button
  #  allowSaveForLater: defaults to true
  compileForm: (form, options={}) ->
    # Check schema version
    if form._schema < require('./index').minSchemaVersion
      throw new Error("Schema version too low")
    if form._schema > require('./index').schemaVersion
      throw new Error("Schema version too high")

    # Create localizer
    T = @createLocalizer(form)

    # Compile contents
    if formUtils.isSectioned(form) 
      # Compile sections
      sections = _.map form.contents, (item) => @compileSection(item, T, form)

      # Create Sections view
      sectionsView = new Sections({ 
        sections: sections
        model: @model
        ctx: @ctx
        T: T
        submitLabel: options.submitLabel
        discardLabel: options.discardLabel
        allowSaveForLater: if options.allowSaveForLater? then options.allowSaveForLater else true
      })
      contents = [sectionsView]

    else
      # Compile into FormControls
      contents = _.map form.contents, (item) => @compileItem(item, T, form)
      formControls = new FormControls({
        contents: contents
        model: @model
        ctx: @ctx
        T: T
        submitLabel: options.submitLabel
        discardLabel: options.discardLabel
        allowSaveForLater: if options.allowSaveForLater? then options.allowSaveForLater else true
        })
      contents = [formControls]

    # If preloaded entity, load it
    if options.entity
      # Find entity question
      if options.entityQuestionId
        question = formUtils.findItem(form, options.entityQuestionId)
        if question._type != "EntityQuestion" 
          throw new Error("Not entity question")
        if question.entityType != options.entityType
          throw new Error("Wrong entity type")
      else
        # Pick first matching
        question = formUtils.findEntityQuestion(form, options.entityType)

      # Check entity question
      if not question
        throw new Error("Entity question not found")

      # Load data
      @compileLoadLinkedAnswers(question.propertyLinks)(options.entity)

      # Set entity
      entry = @model.get(question._id) || {}
      entry = _.clone(entry)

      if question._type == "EntityQuestion"
        entry.value = options.entity._id
      else if question._type == "SiteQuestion"
        entry.value = { code: options.entity.code }

      @model.set(question._id, entry)

    return new FormView({
      model: @model
      id: form._id
      ctx: @ctx
      T: T
      name: @compileString(form.name)
      contents: contents
    })
