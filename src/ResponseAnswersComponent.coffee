PropTypes = require('prop-types')
_ = require 'lodash'
React = require 'react'
H = React.DOM
R = React.createElement

formUtils = require './formUtils'
moment = require 'moment'
ezlocalize = require 'ez-localize'
ui = require 'react-library/lib/bootstrap'
AsyncLoadComponent = require('react-library/lib/AsyncLoadComponent')
VisibilityCalculator = require './VisibilityCalculator'
ResponseRow = require './ResponseRow'

ImageDisplayComponent = require './ImageDisplayComponent'
EntityDisplayComponent = require './EntityDisplayComponent'
AdminRegionDisplayComponent = require './AdminRegionDisplayComponent'

AquagenxCBTDisplayComponent = require './answers/AquagenxCBTDisplayComponent'


# Displays the answers of a response in a table
module.exports = class ResponseAnswersComponent extends AsyncLoadComponent
  @propTypes:
    formDesign: PropTypes.object.isRequired
    data: PropTypes.object.isRequired
    schema: PropTypes.object.isRequired  # Schema of the 

    hideEmptyAnswers: PropTypes.bool # True to hide empty answers

    locale: PropTypes.string # Defaults to english
    T: PropTypes.func.isRequired  # Localizer to use
    formCtx: PropTypes.object.isRequired    # Form context to use

    prevData: PropTypes.object # Previous data
    showPrevAnswers: PropTypes.bool
    highlightChanges: PropTypes.bool
    hideUnchangedAnswers: PropTypes.bool
    showChangedLink: PropTypes.bool
    onChangedLinkClick: PropTypes.func
    onCompleteHistoryLinkClick: PropTypes.func

  # Check if form design or data are different
  isLoadNeeded: (newProps, oldProps) ->
    return not _.isEqual(newProps.formDesign, oldProps.formDesign) or not _.isEqual(newProps.data, oldProps.data) 

  # Call callback with state changes
  load: (props, prevProps, callback) ->
    responseRow = new ResponseRow({
      responseData: props.data
      formDesign: props.formDesign
      getEntityById: props.formCtx.getEntityById
      getEntityByCode: props.formCtx.getEntityByCode
    })

    # Calculate visibility asynchronously
    new VisibilityCalculator(props.formDesign).createVisibilityStructure(props.data, responseRow, (error, visibilityStructure) =>
      callback(error: error, visibilityStructure: visibilityStructure)
    )

  handleLocationClick: (location) ->
    if @props.formCtx.displayMap
      @props.formCtx.displayMap(location)

  renderLocation: (location) ->
    if location
      return H.div null, 
        H.a onClick: @handleLocationClick.bind(this, location), style: { cursor: "pointer" },
          "#{location.latitude}\u00B0 #{location.longitude}\u00B0"
          if location.accuracy then "(+/-) #{location.accuracy} m"

  renderAnswer: (q, answer) ->
    if not answer
      return null

    # Handle alternates
    if answer.alternate
      switch answer.alternate 
        when "na"
          return H.em null, @props.T("Not Applicable")
        when "dontknow"
          return H.em null, @props.T("Don't Know")

    if not answer.value?
      return null

    switch formUtils.getAnswerType(q)
      when "text"
        # Format as url if url
        if answer.value and answer.value.match(/^((([A-Za-z]{3,9}:(?:\/\/)?)(?:[\-;:&=\+\$,\w]+@)?[A-Za-z0-9\.\-]+|(?:www\.|[\-;:&=\+\$,\w]+@)[A-Za-z0-9\.\-]+)((?:\/[\+~%\/\.\w\-_]*)?\??(?:[\-\+=&;%@\.\w_]*)#?(?:[\.\!\/\\\w]*))?)$/)
          # Open in system window if in cordova
          target = if window.cordova? then "_system" else "_blank"
          return H.a href: answer.value, target: target, 
            answer.value

        return answer.value
      when "number"
        return "" + answer.value
      when "choice"
        choice = _.findWhere(q.choices, { id: answer.value })
        if choice
          label = formUtils.localizeString(choice.label, @props.locale)
          if answer.specify?
            specify = answer.specify[answer.value]
          else
            specify = null

          return H.div null,
            label
            if specify 
              ": "  
              H.em null, specify
        else
          return H.span className: "label label-danger", "Invalid Choice"
      when "choices"
        return _.map answer.value, (v) => 
          choice = _.findWhere(q.choices, { id: v })
          if choice
            return H.div null, 
              formUtils.localizeString(choice.label, @props.locale)
              if answer.specify? and answer.specify[v]
                ": "
                H.em null, answer.specify[v]
          else 
            return H.div className: "label label-danger", "Invalid Choice"
  
      when "date"
        # Depends on precision
        if answer.value.length <= 7   # YYYY or YYYY-MM
          return H.div null, answer.value
        else if answer.value.length <= 10 # Date
          return H.div null, moment(answer.value).format("LL")
        else
          return H.div null, moment(answer.value).format("LLL")

      when "units"
        if answer.value and answer.value.quantity? and answer.value.units?
          # Find units
          units = _.findWhere(q.units, { id: answer.value.units })

          valueStr = "" + answer.value.quantity
          unitsStr = if units then formUtils.localizeString(units.label, @props.locale) else "(Invalid)"

          if q.unitsPosition == "prefix" 
            return H.div null,
              H.em null, unitsStr
              " "
              valueStr
          else 
            return H.div null,
              valueStr
              " "
              H.em null, unitsStr

      when "boolean"
        return if answer.value then @props.T("True") else @props.T("False")

      when "location"
        return @renderLocation(answer.value)

      when "image"
        if answer.value
          return R(ImageDisplayComponent, image: answer.value, imageManager: @props.formCtx.imageManager, T: @props.T)

      when "images"
        return _.map answer.value, (img) =>
          R(ImageDisplayComponent, image: img, imageManager: @props.formCtx.imageManager, T: @props.T)

      when "texts"
        return _.map answer.value, (txt) =>
          H.div null, txt

      when "site"
        code = answer.value
        # TODO Eventually always go to code parameter. Legacy responses used code directly as value.
        if _.isObject(code)
          code = code.code

        # Convert to new entity type
        siteType = (if q.siteTypes then q.siteTypes[0]) or "Water point" 
        entityType = siteType.toLowerCase().replace(new RegExp(' ', 'g'), "_")

        return R(EntityDisplayComponent, {
          entityCode: code
          entityType: entityType
          getEntityByCode: @props.formCtx.getEntityByCode
          renderEntityView: @props.formCtx.renderEntitySummaryView
          T: @props.T
        })

      when "entity"
        return R(EntityDisplayComponent, {
          entityId: answer.value
          entityType: q.entityType
          getEntityById: @props.formCtx.getEntityById
          renderEntityView: @props.formCtx.renderEntitySummaryView
          T: @props.T
        })

      when "admin_region"
        return R(AdminRegionDisplayComponent, {
          getAdminRegionPath: @props.formCtx.getAdminRegionPath
          value: answer.value
          T: @props.T
        })

      when "items_choices"
        for item in q.items
          choiceId = answer.value[item.id]
          if choiceId?
            choice = _.findWhere(q.choices, { id: choiceId })
            if choice?
              return H.div null,
                formUtils.localizeString(choice.label, @props.locale)
            else
              return H.span className: "label label-danger", "Invalid Choice"

      when "aquagenx_cbt"
        return R AquagenxCBTDisplayComponent, 
          value: answer.value
          questionId: q._id
          imageManager: @props.formCtx.imageManager

  # Special render on multiple rows
  renderMatrixAnswer: (q, answer, prevAnswer) ->
    if not answer
      return null
    if answer.alternate
      return null
    if not answer.value?
      return null

    if formUtils.getAnswerType(q) == "items_choices"
      contents = []
      for item in q.items
        itemTd = H.td style: {textAlign: "center"},
          formUtils.localizeString(item.label, @props.locale)
        choiceId = answer.value[item.id]
        if choiceId?
          choice = _.findWhere(q.choices, { id: choiceId })
          if choice?
            contents.push H.tr null,
              itemTd,
              H.td null,
                formUtils.localizeString(choice.label, @props.locale)
          else
            contents.push H.tr null,
              itemTd,
              H.td null,
                H.span className: "label label-danger", "Invalid Choice"

          if @props.showPrevAnswers and prevAnswer
            choiceId = prevAnswer.value[item.id]
            if choiceId?
              choice = _.findWhere(q.choices, { id: choiceId })
              if choice?
                contents.push H.tr null,
                  itemTd,
                  H.td null,
                    formUtils.localizeString(choice.label, @props.locale)
              else
                contents.push H.tr null,
                  itemTd,
                  H.td null,
                    H.span className: "label label-danger", "Invalid Choice"
      return contents
    else
      return null


  renderQuestion: (q, dataId) ->
    # Get answer
    dataIds = dataId.split('.')
    if dataIds.length == 1
      answer = @props.data[dataId]
    else
      rosterData = @props.data[dataIds[0]]
      if rosterData.value?
        rosterData = rosterData.value
        answer = rosterData[dataIds[1]][dataIds[2]]
      else
        answer = rosterData[dataIds[1]].data[dataIds[2]]

    # Do not display if empty and hide empty true
    if @props.hideEmptyAnswers and not answer?.value? and not answer?.alternate
      return null

    prevAnswer = null
    trProps = 
      key: dataId

    if @props.prevData
      if dataIds.length == 1
        prevAnswer = @props.prevData.data[dataId]
      else
        prevRosterData = @props.prevData.data[dataIds[0]]
        if prevRosterData?
          if prevRosterData.value?
            prevRosterData = prevRosterData.value
            prevAnswer = prevRosterData[dataIds[1]]?[dataIds[2]]
          else
            prevAnswer = prevRosterData[dataIds[1]]?.data[dataIds[2]]

    matrixAnswer = @renderMatrixAnswer(q, answer, prevAnswer)

    # If both answer and previous answer are falsy
    if not prevAnswer and not answer?.value? and @props.hideUnchangedAnswers
      return null

    if not _.isEqual(prevAnswer?.value, answer?.value) or not _.isEqual(prevAnswer?.specify, answer?.specify)
      if @props.highlightChanges
        trProps['style'] = { background: '#ffd'}
    else 
      if @props.hideUnchangedAnswers
        return null

    return [
      H.tr trProps,
        H.td key: "name", style: { width: "50%" },
          formUtils.localizeString(q.text, @props.locale)
        H.td key: "value",
          H.div null,
            if not matrixAnswer?
              @renderAnswer(q, answer)
            if answer and answer.timestamp
              
                @props.T('Answered')
                ": "
                moment(answer.timestamp).format('llll')
            if answer and answer.location
              @renderLocation(answer.location)
            
            if prevAnswer? and not _.isEqual(prevAnswer.value, answer?.value) and @props.showChangedLink
              H.a style: { float: 'right', display: 'inline-block', cursor: 'pointer', fontSize: 9 }, onClick: @props.onChangedLinkClick, key: 'view_change',
                R ui.Icon, id: "glyphicon-pencil"
                " " 
                T("Edited")

        if @props.showPrevAnswers and @props.prevData
          H.td key: "prevValue",
            if prevAnswer? and not _.isEqual(prevAnswer.value, answer?.value) and @props.onCompleteHistoryLinkClick
              H.a style: { float: 'right', display: 'inline-block', cursor: 'pointer', fontSize: 9 }, onClick: @props.onCompleteHistoryLinkClick, key: 'view_history',
                T("Show Changes")

            if not prevMatrixAnswer?
              @renderAnswer(q, prevAnswer)
            if prevAnswer and prevAnswer.timestamp
              H.div null,
                @props.T('Answered')
                ": "
                moment(prevAnswer.timestamp).format('llll')
            if prevAnswer and prevAnswer.location
              @renderLocation(prevAnswer.location)
      matrixAnswer
    ]

  # Add all the items with the proper rosterId to items array
  # Looks inside groups and sections
  collectItemsReferencingRoster: (items, contents, rosterId) ->
    # Get the contents of all the other question that are referencing this roster
    for otherItem in contents
      if otherItem._type == 'Group' or otherItem._type == 'Section'
        @collectItemsReferencingRoster(items, otherItem.contents, rosterId)
      if otherItem.rosterId == rosterId
        items.push.apply(items, otherItem.contents);

  # dataId is the key used for looking up the data + testing visibility
  # dataId is simply item._id except for rosters children
  renderItem: (item, visibilityStructure, dataId) ->
    if not visibilityStructure[dataId]
      return

    colspan = if (@props.showPrevAnswers and @props.prevData) then 3 else 2
    # Sections and Groups behave the same
    if item._type == "Section" or item._type == "Group"
      contents = _.map item.contents, (item) =>
        @renderItem(item, visibilityStructure, item._id)

      # Remove nulls
      contents = _.compact(contents)

      # Do not display if empty
      if contents.length == 0
        return null

      return [
        H.tr key: item._id,
          H.td colSpan: colspan, style: { fontWeight: "bold" },
            formUtils.localizeString(item.name, @props.locale)
        contents
      ]

    # RosterMatrices and RosterGroups behave the same
    # Only the one storing the data will display it
    # The rosters referencing another one will display a simple text to say so
    if item._type == "RosterMatrix" or item._type == "RosterGroup"
      items = []

      # Simply display a text referencing the other roster if a reference
      if item.rosterId?
        # Unless hiding empty, in which case blank
        if @props.hideEmptyAnswers
          return null

        referencedRoster = formUtils.findItem(@props.formDesign, item.rosterId)
        return H.tr null,
          H.td style: { fontWeight: "bold" },
            formUtils.localizeString(item.name, @props.locale)
          H.td colSpan: colspan-1,
            H.span style: {fontStyle: 'italic'},
              @props.T("Data is stored in {0}", formUtils.localizeString(referencedRoster.name, @props.locale))

      # Get the data for that roster
      data = @props.data[item._id]

      if (not data or data.length == 0) and @props.hideEmptyAnswers
        return null

      # Get the questions of the other rosters referencing this one
      items = _.clone(item.contents)
      @collectItemsReferencingRoster(items, @props.formDesign.contents, item._id)
      
      return [
        H.tr key: item._id,
          H.td colSpan: colspan, style: { fontWeight: "bold" },
            formUtils.localizeString(item.name, @props.locale)

        if data?
          # For each entry in data
          for entry, index in data
            contents = _.map items, (childItem) =>
              dataId = "#{item._id}.#{index}.#{childItem._id}"
              @renderItem(childItem, visibilityStructure, dataId)

            # Remove nulls
            contents = _.compact(contents)

            # Do not display if empty
            if contents.length == 0
              null
            else
              [
                # Display the index of the answer
                H.tr null,
                  H.td colSpan: colspan, style: { fontWeight: "bold" },
                    "#{index+1}."
                # And the answer for each question
                contents
              ]
      ]

    if item._type == "MatrixQuestion"
      answer = @props.data[dataId]
      if answer?.value?
        rows = []
        rows.push H.tr key: item._id,
          H.td colSpan: colspan, style: { fontWeight: "bold" },
            formUtils.localizeString(item.name, @props.locale)
        for rowItem in item.items
          itemValue = answer.value[rowItem.id]
          if itemValue
            rows.push H.tr null,
              H.td colSpan: colspan, style: { fontStyle: 'italic' },
                formUtils.localizeString(rowItem.label, @props.locale)
            for column in item.columns
              if itemValue[column._id]
                dataId = "#{item._id}.#{rowItem.id}.#{column._id}"
                rows.push @renderItem(column, visibilityStructure, dataId)
        return rows
      else
        return null

    if formUtils.isQuestion(item)
      return @renderQuestion(item, dataId)

  render: ->
    if @state.error
      return H.div className: "alert alert-danger", 
        @state.error.message

    if not @state.visibilityStructure
      return H.div null, "Loading..."

    H.table className: "table table-bordered table-condensed", style: { marginBottom: 0 },
      H.thead null,
        H.tr null,
          H.th null, "Question"
          H.th null, "Answer"
          if @props.showPrevAnswers
            H.th null, "Original Answer"
      H.tbody null, 
        _.map @props.formDesign.contents, (item) =>
          @renderItem(item, @state.visibilityStructure, item._id)

