assert = require('chai').assert
VisibilityCalculator = require '../src/VisibilityCalculator'

describe 'VisibilityCalculator', ->
  before ->
    @form = {_type: 'Form', contents: [
        {
          _id: "sectionId"
          _type: "Section"
          contents: [
            {
              _id: "checkboxQuestionId",
              _type: "CheckQuestion",
              required: false,
              alternates: {
                na: true,
                dontknow: true
              },
              conditions: [],
              validations: []
            },

            {
              _id: "groupId",
              _type: "Group",
              conditions: [{op: "true", lhs: {question: "checkboxQuestionId"}}],
              validations: [],
              contents: [
                {
                  _id: "groupQuestionId",
                  _type: "TextQuestion",
                  required: false,
                  conditions: [],
                  validations: []
                },
              ]
            },


            {
              _id: "mainRosterGroupId",
              _type: "RosterGroup",
              required: false,
              conditions: [],
              validations: []
              contents: [
                {
                  _id: "firstRosterQuestionId",
                  _type: "TextQuestion",
                  required: false,
                  alternates: {
                    na: false,
                    dontknow: false
                  },
                  conditions: [],
                  validations: []
                },
                {
                  _id: "secondRosterQuestionId",
                  _type: "TextQuestion",
                  required: false,
                  alternates: {
                    na: false,
                    dontknow: false
                  },
                  conditions: [
                    {op: "present", lhs: {question: "firstRosterQuestionId"}}
                  ],
                  validations: []
                },
              ]
            },
            {
              _id: "subRosterGroupId",
              _type: "RosterGroup",
              rosterId: "mainRosterGroupId",
              required: false,
              conditions: [],
              validations: []
              contents: [
                {
                  _id: "firstSubRosterQuestionId",
                  _type: "TextQuestion",
                  required: false,
                  alternates: {
                    na: false,
                    dontknow: false
                  },
                  conditions: [],
                  validations: []
                }
              ]
            }
          ]
        }
      ]
    }

  describe 'createVisibilityStructure', ->
    beforeEach ->
      @visibilityCalculator = new VisibilityCalculator(@form)

    it 'create a complete visibility structure', (done) ->
      data = {
        mainRosterGroupId: [
          { data: {firstRosterQuestionId: {value: 'some text'}, firstSubRosterQuestionId: {value: 'sub text'}} }
          # This will make the second question invisible
          { data: {firstRosterQuestionId: {value: null}} }
        ]
      }
      @visibilityCalculator.createVisibilityStructure data, (error, visibilityStructure) =>
        expectedVisibilityStructure = {
          'sectionId': true
          'checkboxQuestionId': true
          'mainRosterGroupId': true
          'mainRosterGroupId.0.firstRosterQuestionId': true
          'mainRosterGroupId.0.secondRosterQuestionId': true
          'mainRosterGroupId.1.firstRosterQuestionId': true
          'mainRosterGroupId.1.secondRosterQuestionId': false
          # Questions under subRosterGroup need to use the mainRosterGroup id.
          # This makes the data cleaning easier.
          'mainRosterGroupId.0.firstSubRosterQuestionId': true
          'mainRosterGroupId.1.firstSubRosterQuestionId': true
          'subRosterGroupId': true
          groupId: false
          groupQuestionId: false
        }
        assert.deepEqual visibilityStructure, expectedVisibilityStructure
        done()

  describe 'processQuestion', ->
    beforeEach ->
      @visibilityCalculator = new VisibilityCalculator(@form)

    describe "TextQuestion", ->
      it 'sets visibility to false if forceToInvisible is set to true', (done) ->
        data = {}

        question = {_id: 'testId'}
        visibilityStructure = {}
        @visibilityCalculator.processQuestion(question, true, data, visibilityStructure, '', (error) =>
          assert.deepEqual {testId: false}, visibilityStructure
          done()
        )

      it 'sets visibility using the prefix', (done) ->
        data = {}
        question = {_id: 'testId'}
        visibilityStructure = {}
        @visibilityCalculator.processQuestion(question, false, data, visibilityStructure, 'testprefix.', (error) =>
          assert.deepEqual {'testprefix.testId': true}, visibilityStructure
          done()
        )

      it 'sets visibility to true if conditions is null, undefined or empty', (done) ->
        data = {}

        question = {_id: 'testId'}
        visibilityStructure = {}
        @visibilityCalculator.processQuestion(question, false, data, visibilityStructure, '', (error) =>
          assert.deepEqual {testId: true}, visibilityStructure

          question = {_id: 'testId', conditions: null}
          visibilityStructure = {}
          @visibilityCalculator.processQuestion(question, false, data, visibilityStructure, '', (error) =>
            assert.deepEqual {testId: true}, visibilityStructure

            question = {_id: 'testId', conditions: []}
            visibilityStructure = {}
            @visibilityCalculator.processQuestion(question, false, data, visibilityStructure, '', (error) =>
              assert.deepEqual {testId: true}, visibilityStructure
              done()
            )
          )
        )


      it 'sets visibility to true if conditions is true', (done) ->
        data = {checkboxQuestionId: {value: true}}
        question = {
          _id: 'testId'
          conditions: [
            {op: "true", lhs: {question: "checkboxQuestionId"}}
          ]
        }
        visibilityStructure = {}
        @visibilityCalculator.processQuestion(question, false, data, visibilityStructure, '', (error) =>
          assert.deepEqual {testId: true}, visibilityStructure
          done()
        )

      it 'sets visibility to false if conditions is false', (done) ->
        data = {checkboxQuestionId: {value: false}}
        question = {
          _id: 'testId'
          conditions: [
            {op: "true", lhs: {question: "checkboxQuestionId"}}
          ]
        }
        visibilityStructure = {}
        @visibilityCalculator.processQuestion(question, false, data, visibilityStructure, '', (error) =>
          assert.deepEqual {testId: false}, visibilityStructure
          done()
        )


  describe 'processGroup', ->
    it 'sub questions are invisible if the section is invisible', (done) ->
      form = {_type: 'Form', contents: [
          {
            _id: "firstSectionId"
            _type: "Section"
            contents: [
              {
                _id: "checkboxQuestionId",
                _type: "CheckQuestion",
                required: false,
                alternates: {
                  na: true,
                  dontknow: true
                },
                conditions: [],
                validations: []
              }
            ]
          },
          {
            _id: "secondSectionId"
            _type: "Section"
            conditions: [
              {op: "true", lhs: {question: "checkboxQuestionId"}}
            ]
            contents: [
              {
                _id: "anotherQuestionId",
                _type: "CheckQuestion",
                required: false,
                alternates: {
                  na: true,
                  dontknow: true
                },
                conditions: [],
                validations: []
              }
            ]
          }
        ]
      }
      
      visibilityCalculator = new VisibilityCalculator(form)
      visibilityStructure = {}
      data = {}

      firstSection = form.contents[0]
      visibilityCalculator.processGroup(firstSection, false, data, visibilityStructure, '', (error) =>
        assert.deepEqual {firstSectionId: true, checkboxQuestionId: true}, visibilityStructure

        secondSection = form.contents[1]
        visibilityCalculator.processGroup(secondSection, true, data, visibilityStructure, '', (error) =>
          assert.deepEqual {firstSectionId: true, checkboxQuestionId: true, secondSectionId: false, anotherQuestionId: false}, visibilityStructure
          done()
        )
      )

