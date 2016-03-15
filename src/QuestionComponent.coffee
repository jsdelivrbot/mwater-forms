_ = require 'lodash'
React = require 'react'
H = React.DOM
R = React.createElement

formUtils = require './formUtils'
markdown = require("markdown").markdown
ImageEditorComponent = require './ImageEditorComponent'
ImagelistEditorComponent = require './ImagelistEditorComponent'
AdminRegionAnswerComponent = require './AdminRegionAnswerComponent'
EntityAnswerComponent = require './EntityAnswerComponent'
LocationEditorComponent = require './LocationEditorComponent'

# Question component that displays a question of any type.
# Displays question text and hint
# Displays toggleable help 
# Displays required (*)
# Displays comments field
# Goes to next question when enter or tab is pressed on previous question
# Goes to comments field when enter or tab is pressed on 
# Does NOT fill in when sticky and visible for first time. This is done by data cleaning
# Does NOT remove answer when invisible. This is done by data cleaning
# Does not check conditions or make self invisible. This is done by parent component.
# Displays alternates and makes exclusive with answer
# Records timestamp when answered
# Records GPS when answered
# Displays validation errors and not answered errors when told to from above.
# Allows focusing on question which scrolls into view
module.exports = class QuestionComponent extends React.Component
  @contextTypes:
    locale: React.PropTypes.string
    selectEntity: React.PropTypes.func
    editEntity: React.PropTypes.func
    renderEntitySummaryView: React.PropTypes.func.isRequired

    getEntityById: React.PropTypes.func
    getEntityByCode: React.PropTypes.func

    locationFinder: React.PropTypes.object
    displayMap: React.PropTypes.func # Takes location ({ latitude, etc.}) and callback (called back with new location)
    storage: React.PropTypes.object   # Storage object for saving location
    
    getAdminRegionPath: React.PropTypes.func.isRequired # Call with (id, callback). Callback (error, [{ id:, level: <e.g. 1>, name: <e.g. Manitoba>, type: <e.g. Province>}] in level ascending order)
    getSubAdminRegions: React.PropTypes.func.isRequired # Call with (id, callback). Callback (error, [{ id:, level: <e.g. 1>, name: <e.g. Manitoba>, type: <e.g. Province>}] of admin regions directly under the specified id)
    findAdminRegionByLatLng: React.PropTypes.func.isRequired # Call with (lat, lng, callback). Callback (error, id)

    imageManager: React.PropTypes.object.isRequired
    imageAcquirer: React.PropTypes.object

  @propTypes:
    question: React.PropTypes.object.isRequired # Design of question. See schema
    answer: React.PropTypes.object      # Current answer. Contains { value: <some value> } usually. See docs/Answer Formats.md
    onAnswerChange: React.PropTypes.func.isRequired

  @defaultProps:
    answer: {}  # Default to {}

  constructor: ->
    super

    @state = {
      helpVisible: false    # True to display help
    }

  handleToggleHelp: =>
    @setState(helpVisible: not @state.helpVisible)

  handleValueChange: (value) =>
    @props.onAnswerChange(_.extend({}, @props.answer, { value: value }))

  handleAlternate: (alternate) =>
    # Clear value, specify and set alternate
    @props.onAnswerChange(_.extend({}, @props.answer, { 
      value: null
      specify: null
      alternate: if @props.answer.alternate == alternate then null else alternate
    }))

  handleCommentsChange: (ev) =>
    @props.onAnswerChange(_.extend({}, @props.answer, { comments: ev.target.value }))

  handleSpecifyChange: (specify) =>
    @props.onAnswerChange(_.extend({}, @props.answer, { specify: specify }))

  renderPrompt: ->
    H.div className: "prompt",
      if @props.question.code
        H.span className: "question-code", options.code + ": "

      # Prompt
      formUtils.localizeString(@props.question.text, @context.locale)

      # Required star
      if @props.question.required
        H.span className: "required", "*"

      if @props.question.help
        H.button type: "button", className: "btn btn-link btn-sm", onClick: @handleToggleHelp,
          H.span className: "glyphicon glyphicon-question-sign"

  renderHint: ->
    if @props.question.hint
      H.div className: "text-muted", formUtils.localizeString(@props.question.hint, @context.locale)

  renderHelp: ->
    if @state.helpVisible and @props.question.help
      H.div className: "help well well-sm", dangerouslySetInnerHTML: { __html: markdown.toHTML(formUtils.localizeString(@props.question.help, @context.locale)) }

  renderAlternates: ->
    if @props.question.alternates and (@props.question.alternates.na or @props.question.alternates.dontknow)
      H.div null,
        if @props.question.alternates.dontknow
          H.div className: "touch-checkbox alternate #{if @props.answer.alternate == 'dontknow' then 'checked'}", onClick: @handleAlternate.bind(null, 'dontknow'),
            T("Don't Know")
        if @props.question.alternates.na
          H.div className: "touch-checkbox alternate #{if @props.answer.alternate == 'na' then 'checked'}", onClick: @handleAlternate.bind(null, 'na'),
            T("Not Applicable")

  renderCommentsField: ->
    if @props.question.commentsField
      H.textarea className: "form-control question-comments", placeholder: T("Comments"), value: @props.answer.comments, onChange: @handleCommentsChange

  renderAnswer: ->
    switch @props.question._type
      when "TextQuestion"
        # TODO multiline
        return R TextAnswerComponent, value: @props.answer.value, onValueChange: @handleValueChange

      when "NumberQuestion"
        return R NumberAnswerComponent, value: @props.answer.value, onValueChange: @handleValueChange, decimal: @props.question.decimal

      when "DropdownQuestion"
        return R DropdownAnswerComponent, {
          choices: @props.question.choices
          value: @props.answer.value
          onValueChange: @handleValueChange
          specify: @props.answer.specify
          onSpecifyChange: @handleSpecifyChange
        }

      when "RadioQuestion"
        return R RadioAnswerComponent, {
          choices: @props.question.choices
          value: @props.answer.value
          onValueChange: @handleValueChange
          specify: @props.answer.specify
          onSpecifyChange: @handleSpecifyChange
        }

      when "MulticheckQuestion"
        return "choices"
      when "DateQuestion" # , "DateTimeQuestion"??
        return "date"
      when "UnitsQuestion"
        return "units"
      when "CheckQuestion"
        return "boolean"
      when "LocationQuestion"
        R LocationAnswerComponent,
          value: @props.answer.value
          onValueChange: @handleValueChange
          storage: @context.storage
          displayMap: @context.displayMap

        return "location"

      when "ImageQuestion"
        return R ImageEditorComponent,
          imageManager: @context.imageManager
          imageAcquirer: @context.imageAcquirer
          image: @props.answer.value
          onImageChange: @handleValueChange 

      when "ImagesQuestion"
        return R ImageEditorComponent,
          imageManager: @context.imageManager
          imageAcquirer: @context.imageAcquirer
          imagelist: @props.answer.value
          onImagelistChange: @handleValueChange

      when "TextListQuestion"
        return "texts"
      when "SiteQuestion"
        return "site"
      when "BarcodeQuestion"
        return "text"

      when "EntityQuestion"
        R EntityAnswerComponent,
          value: @props.answer.value
          entityType: @props.question.entityType
          onValueChange: @handleValueChange

      when "AdminRegionQuestion"
        return R AdminRegionAnswerComponent,
          locationFinder: @context.locationFinder
          displayMap: @context.displayMap
          getAdminRegionPath: @context.getAdminRegionPath
          getSubAdminRegions: @context.getSubAdminRegions
          findAdminRegionByLatLng: @context.findAdminRegionByLatLng
          value: @props.answer.value
          onChange: @handleValueChange

      else
        return "Unknown type #{@props.question._type}"
    return null

  render: ->
    H.div className: "question",
      @renderPrompt()
      @renderHint()
      @renderHelp()

      H.div className: "answer",
        @renderAnswer()

      @renderAlternates()
      @renderCommentsField()

class TextAnswerComponent extends React.Component
  @propTypes:
    value: React.PropTypes.string
    onValueChange: React.PropTypes.func.isRequired

  render: ->
    H.input className: "form-control", type: "text", value: @props.value, onChange: (ev) => @props.onValueChange(ev.target.value)

class NumberAnswerComponent extends React.Component
  constructor: ->
    super

    # Parsing happens on blur
    @state = {
      inputText: if @props.value? then "" + @props.value else ""
    }

  @propTypes:
    decimal: React.PropTypes.bool.isRequired
    value: React.PropTypes.string
    onValueChange: React.PropTypes.func.isRequired

  componentWillReceiveProps: (nextProps) ->
    # If different, override text
    if nextProps.value != @props.value
      @setState(inputText: if nextProps.value? then "" + nextProps.value else "")

  handleBlur: =>
    # Parse and set value
    if @isValid()
      val = if @props.decimal then parseFloat(@state.inputText) else parseInt(@state.inputText)
      if isNaN(val)
        @props.onValueChange(null)
      else
        @props.onValueChange(val)

  # Check regex matching of numbers
  isValid: ->
    if @state.inputText.length == 0
      return true

    if @props.decimal
      return @state.inputText.match(/^-?[0-9]*\.?[0-9]+$/) and not isNaN(parseFloat(@state.inputText))
    else
      return @state.inputText.match(/^-?\d+$/)

  render: ->
    H.input 
      type: "text"
      className: "form-control"
      value: @state.inputText
      onChange: (ev) => @setState(inputText: ev.target.value)
      onBlur: @handleBlur


class DropdownAnswerComponent extends React.Component
  @contextTypes:
    locale: React.PropTypes.string  # Current locale (e.g. "en")

  @propTypes:
    choices: React.PropTypes.arrayOf(React.PropTypes.shape({
        # Unique (within the question) id of the choice. Cannot be "na" or "dontknow" as they are reserved for alternates
        id: React.PropTypes.string.isRequired

        # Label of the choice, localized
        label: React.PropTypes.object.isRequired

        # Hint associated with a choice
        hint: React.PropTypes.object

        # True to require a text field to specify the value when selected
        # Usually used for "Other" options.
        # Value is stored in specify[id]
        specify: React.PropTypes.bool
      })).isRequired
    value: React.PropTypes.string
    onValueChange: React.PropTypes.func.isRequired
    specify: React.PropTypes.object # See answer format
    onSpecifyChange: React.PropTypes.func.isRequired

  @defaultProps: 
    specify: {}

  handleValueChange: (ev) =>
    if ev.target.value
      @props.onValueChange(ev.target.value)
    else
      @props.onValueChange(null)

  handleSpecifyChange: (id, ev) =>
    change = {}
    change[id] = ev.target.value
    specify = _.extend({}, @props.specify, change)
    @props.onSpecifyChange(specify)

  # Render specify input box
  renderSpecify: ->
    choice = _.findWhere(@props.choices, { id: @props.value })
    if choice and choice.specify
      H.input className: "form-control specify-input", type: "text", value: @props.specify[choice.id], onChange: @handleSpecifyChange.bind(null, choice.id)

  render: ->
    H.div null,
      H.select className: "form-control", style: { width: "auto" }, value: @props.value, onChange: @handleValueChange,
        H.option key: "__none__", value: ""
        _.map @props.choices, (choice) =>
          H.option key: choice.id, value: choice.id, 
            formUtils.localizeString(choice.label, @context.locale) 
            if choice.hint
              " (" + formUtils.localizeString(choice.hint, @context.locale) + ")"

      @renderSpecify()

class RadioAnswerComponent extends React.Component
  @contextTypes:
    locale: React.PropTypes.string  # Current locale (e.g. "en")

  @propTypes:
    choices: React.PropTypes.arrayOf(React.PropTypes.shape({
        # Unique (within the question) id of the choice. Cannot be "na" or "dontknow" as they are reserved for alternates
        id: React.PropTypes.string.isRequired

        # Label of the choice, localized
        label: React.PropTypes.object.isRequired

        # Hint associated with a choice
        hint: React.PropTypes.object

        # True to require a text field to specify the value when selected
        # Usually used for "Other" options.
        # Value is stored in specify[id]
        specify: React.PropTypes.bool
      })).isRequired
    value: React.PropTypes.string
    onValueChange: React.PropTypes.func.isRequired
    specify: React.PropTypes.object # See answer format
    onSpecifyChange: React.PropTypes.func.isRequired

  @defaultProps: 
    specify: {}

  handleValueChange: (choice) =>
    if choice.id == @props.value
      @props.onValueChange(null)
    else
      @props.onValueChange(choice.id)

  handleSpecifyChange: (id, ev) =>
    change = {}
    change[id] = ev.target.value
    specify = _.extend({}, @props.specify, change)
    @props.onSpecifyChange(specify)

  # Render specify input box
  renderSpecify: ->
    choice = _.findWhere(@props.choices, { id: @props.value })
    if choice and choice.specify
      H.input className: "form-control specify-input", type: "text", value: @props.specify[choice.id], onChange: @handleSpecifyChange.bind(null, choice.id)

  renderChoice: (choice) ->
    H.div key: choice.id,
      H.div className: "touch-radio #{if @props.value == choice.id then "checked" else ""}", onClick: @handleValueChange.bind(null, choice),
        formUtils.localizeString(choice.label, @context.locale)
        if choice.hint
          H.span className: "radio-choice-hint",
            formUtils.localizeString(choice.hint, @context.locale)

      if choice.specify
        @renderSpecify()

  render: ->
    H.div className: "touch-radio-group",
      _.map @props.choices, (choice) => @renderChoice(choice)


class LocationAnswerComponent extends React.Component
  @propTypes:
    value: React.PropTypes.string
    onValueChange: React.PropTypes.func.isRequired
    storage: React.PropTypes.object
    displayMap: React.PropTypes.func

  handleUseMap: ->
    if @props.displayMap?
      @props.displayMap.displayMap(@props.value, (newLoc) =>
        # Wrap to -180, 180
        while newLoc.longitude < -180
          newLoc.longitude += 360
        while newLoc.longitude > 180
          newLoc.longitude -= 360

        # Clip to -85, 85 (for Webmercator)
        if newLoc.latitude > 85
          newLoc.latitude = 85
        if newLoc.latitude < -85
          newLoc.latitude = -85
        @props.onValueChange(newLoc)
      )

  render: ->
    R LocationEditorComponent,
      location: @props.value
      onLocationChange: @props.onValueChange
      onUseMap: @handleUseMap
      storage: @props.storage
      T: global.T # TODO

