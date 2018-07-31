var H, MulticheckAnswerComponent, PropTypes, R, React, _, conditionUtils, formUtils,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty,
  indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

_ = require('lodash');

PropTypes = require('prop-types');

React = require('react');

H = React.DOM;

R = React.createElement;

formUtils = require('../formUtils');

conditionUtils = require('../conditionUtils');

module.exports = MulticheckAnswerComponent = (function(superClass) {
  extend(MulticheckAnswerComponent, superClass);

  function MulticheckAnswerComponent() {
    this.handleSpecifyChange = bind(this.handleSpecifyChange, this);
    this.handleValueChange = bind(this.handleValueChange, this);
    return MulticheckAnswerComponent.__super__.constructor.apply(this, arguments);
  }

  MulticheckAnswerComponent.contextTypes = {
    locale: PropTypes.string
  };

  MulticheckAnswerComponent.propTypes = {
    choices: PropTypes.arrayOf(PropTypes.shape({
      id: PropTypes.string.isRequired,
      label: PropTypes.object.isRequired,
      hint: PropTypes.object,
      specify: PropTypes.bool
    })).isRequired,
    answer: PropTypes.object.isRequired,
    onAnswerChange: PropTypes.func.isRequired,
    data: PropTypes.object.isRequired
  };

  MulticheckAnswerComponent.prototype.focus = function() {
    return null;
  };

  MulticheckAnswerComponent.prototype.handleValueChange = function(choice) {
    var ids, ref, specify;
    ids = this.props.answer.value || [];
    if (ref = choice.id, indexOf.call(ids, ref) >= 0) {
      if (this.props.answer.specify != null) {
        specify = _.clone(this.props.answer.specify);
        if (specify[choice.id] != null) {
          delete specify[choice.id];
        }
      } else {
        specify = null;
      }
      return this.props.onAnswerChange({
        value: _.difference(ids, [choice.id]),
        specify: specify
      });
    } else {
      return this.props.onAnswerChange({
        value: _.union(ids, [choice.id]),
        specify: this.props.answer.specify
      });
    }
  };

  MulticheckAnswerComponent.prototype.handleSpecifyChange = function(id, ev) {
    var change, specify;
    change = {};
    change[id] = ev.target.value;
    specify = _.extend({}, this.props.answer.specify, change);
    return this.props.onAnswerChange({
      value: this.props.answer.value,
      specify: specify
    });
  };

  MulticheckAnswerComponent.prototype.areConditionsValid = function(choice) {
    if (choice.conditions == null) {
      return true;
    }
    return conditionUtils.compileConditions(choice.conditions)(this.props.data);
  };

  MulticheckAnswerComponent.prototype.renderSpecify = function(choice) {
    var value;
    if (this.props.answer.specify != null) {
      value = this.props.answer.specify[choice.id];
    } else {
      value = '';
    }
    return H.input({
      className: "form-control specify-input",
      type: "text",
      value: value,
      onChange: this.handleSpecifyChange.bind(null, choice.id)
    });
  };

  MulticheckAnswerComponent.prototype.renderChoice = function(choice) {
    var ref, selected;
    if (!this.areConditionsValid(choice)) {
      return null;
    }
    selected = _.isArray(this.props.answer.value) && (ref = choice.id, indexOf.call(this.props.answer.value, ref) >= 0);
    return H.div({
      key: choice.id
    }, H.div({
      className: "choice touch-checkbox " + (selected ? "checked" : ""),
      id: choice.id,
      onClick: this.handleValueChange.bind(null, choice)
    }, formUtils.localizeString(choice.label, this.context.locale), choice.hint ? H.span({
      className: "checkbox-choice-hint"
    }, formUtils.localizeString(choice.hint, this.context.locale)) : void 0), choice.specify && selected ? this.renderSpecify(choice) : void 0);
  };

  MulticheckAnswerComponent.prototype.render = function() {
    return H.div(null, _.map(this.props.choices, (function(_this) {
      return function(choice) {
        return _this.renderChoice(choice);
      };
    })(this)));
  };

  return MulticheckAnswerComponent;

})(React.Component);
