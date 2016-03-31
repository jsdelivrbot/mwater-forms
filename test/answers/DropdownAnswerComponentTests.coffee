assert = require('chai').assert

TestComponent = require('react-library/lib/TestComponent')
ReactTestUtils = require('react-addons-test-utils')

DropdownAnswerComponent = require '../../src/answers/DropdownAnswerComponent'

React = require 'react'
ReactDOM = require 'react-dom'
R = React.createElement
H = React.DOM

createOptions = (options) ->
  return _.extend {
    onValueChange: () ->
      null
    value: null
    choices: [
      {
        id: 'a'
        label: {'en': 'label a', '_base': 'en'}
        hint: {'en': 'hint a', '_base': 'en'}
        specify: false
      },
      {
        id: 'b'
        label: {'en': 'label b', '_base': 'en'}
        hint: {'en': 'hint b', '_base': 'en'}
        specify: true
        onSpecifyChange: null
      }
    ]
  }, options

describe 'DropdownAnswerComponent', ->
  beforeEach ->
    @toDestroy = []

    @render = (options = {}) =>
      elem = R(DropdownAnswerComponent, options)
      comp = new TestComponent(elem)
      @toDestroy.push(comp)
      return comp

  afterEach ->
    for comp in @toDestroy
      comp.destroy()

  it 'accepts known value', (done) ->
    testComponent = @render createOptions {
        onValueChange: (value) ->
          assert.equal value, 'a'
          # TODO: test disabled state
          assert false, 'Need to test the disabled state'
          done()
      }

    select = ReactTestUtils.findRenderedDOMComponentWithTag(testComponent.getComponent(), 'select')
    TestComponent.changeValue(select, "a")

  it 'is not disabled with empty value', (done) ->
    testComponent = @render createOptions {
        onValueChange: (value) ->
          assert.equal value, null
          # TODO: test disabled state
          assert false, 'Need to test the disabled state'
          done()
        value: 'a'
      }

    select = ReactTestUtils.findRenderedDOMComponentWithTag(testComponent.getComponent(), 'select')
    TestComponent.changeValue(select, null)

  it 'is not disabled with unknown value', () ->
    testComponent = @render createOptions({value: 'a1'})

    # TODO: test if disabled
    assert false, 'Need to test the disabled state'

  it "displays choices and hints", ->
    testComponent = @render createOptions()

    labelA = testComponent.findComponentByText(/label a/)
    assert labelA?, 'Not showing label a'

    labelB = testComponent.findComponentByText(/label b/)
    assert labelB?, 'Not showing label b'

    hintA = testComponent.findComponentByText(/hint a/)
    assert hintA?, 'Not showing hint a'

    hintB = testComponent.findComponentByText(/hint b/)
    assert hintB?, 'Not showing hint b'

  it "displays specify box when the right choice is selected", ->
    testComponent = @render createOptions {value: 'b'}

    specifyInput = ReactTestUtils.findRenderedDOMComponentWithClass.bind(this, testComponent.getComponent(), 'specify-input')
    assert specifyInput?

  it "it doesn't displays specify box when a choice without specify is selected", ->
    testComponent = @render createOptions {value: 'a'}

    assert.throws(ReactTestUtils.findRenderedDOMComponentWithClass.bind(this, testComponent.getComponent(), 'specify-input'), 'Did not find exactly one match (found: 0) for class:specify-input')

  it "records specify value", (done) ->
    testComponent = @render createOptions {
      onSpecifyChange: (specifyValue) ->
        assert.deepEqual specifyValue, {'b': 'specify'}
        done()
      value: 'b'
    }

    specifyInput = ReactTestUtils.findRenderedDOMComponentWithClass(testComponent.getComponent(), 'specify-input')
    TestComponent.changeValue(specifyInput, 'specify')

  it "removes specify value on other selection", (done) ->
    testComponent = @render createOptions {
      onSpecifyChange: (specifyValue) ->
        assert.deepEqual specifyValue, null
        done()
      value: 'b'
    }

    select = ReactTestUtils.findRenderedDOMComponentWithTag(testComponent.getComponent(), 'select')
    TestComponent.changeValue(select, "b")