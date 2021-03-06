'use strict';

var _getPrototypeOf = require('babel-runtime/core-js/object/get-prototype-of');

var _getPrototypeOf2 = _interopRequireDefault(_getPrototypeOf);

var _classCallCheck2 = require('babel-runtime/helpers/classCallCheck');

var _classCallCheck3 = _interopRequireDefault(_classCallCheck2);

var _createClass2 = require('babel-runtime/helpers/createClass');

var _createClass3 = _interopRequireDefault(_createClass2);

var _possibleConstructorReturn2 = require('babel-runtime/helpers/possibleConstructorReturn');

var _possibleConstructorReturn3 = _interopRequireDefault(_possibleConstructorReturn2);

var _inherits2 = require('babel-runtime/helpers/inherits');

var _inherits3 = _interopRequireDefault(_inherits2);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

var ExprEvaluator, ExprUtils, PropTypes, R, React, TextExprsComponent, _, async, formUtils, markdown;

PropTypes = require('prop-types');

_ = require('lodash');

React = require('react');

R = React.createElement;

async = require('async');

formUtils = require('./formUtils');

ExprEvaluator = require('mwater-expressions').ExprEvaluator;

ExprUtils = require('mwater-expressions').ExprUtils;

markdown = require("markdown").markdown;

// Displays a text string with optional expressions embedded in it that are computed
module.exports = TextExprsComponent = function () {
  var TextExprsComponent = function (_React$Component) {
    (0, _inherits3.default)(TextExprsComponent, _React$Component);

    function TextExprsComponent(props) {
      (0, _classCallCheck3.default)(this, TextExprsComponent);

      var _this = (0, _possibleConstructorReturn3.default)(this, (TextExprsComponent.__proto__ || (0, _getPrototypeOf2.default)(TextExprsComponent)).call(this, props));

      _this.state = {
        exprValueStrs: []
      };
      return _this;
    }

    (0, _createClass3.default)(TextExprsComponent, [{
      key: 'componentWillMount',
      value: function componentWillMount() {
        // Evaluate expressions
        return this.evaluateExprs();
      }
    }, {
      key: 'componentDidUpdate',
      value: function componentDidUpdate() {
        // Evaluate expressions
        return this.evaluateExprs();
      }
    }, {
      key: 'evaluateExprs',
      value: function evaluateExprs() {
        var _this2 = this;

        if (!this.props.exprs || this.props.exprs.length === 0) {
          return;
        }
        // Evaluate each expression
        return async.map(this.props.exprs, function (expr, cb) {
          return new ExprEvaluator(_this2.props.schema).evaluate(expr, {
            row: _this2.props.responseRow
          }, function (error, value) {
            if (error) {
              return cb(null, "<error>");
            }
            // stringify value
            return cb(null, new ExprUtils(_this2.props.schema).stringifyExprLiteral(expr, value, _this2.props.locale));
          });
        }, function (error, valueStrs) {
          // Only update state if changed
          if (!_.isEqual(valueStrs, _this2.state.exprValueStrs)) {
            return _this2.setState({
              exprValueStrs: valueStrs
            });
          }
        });
      }
    }, {
      key: 'render',
      value: function render() {
        var _this3 = this;

        var html, str;
        // Localize string
        str = formUtils.localizeString(this.props.localizedStr, this.props.locale) || "";
        // Perform substitutions ({0}, {1}, etc.)
        str = str.replace(/\{(\d+)\}/g, function (match, index) {
          index = parseInt(index);
          if (_this3.state.exprValueStrs[index] != null) {
            return _this3.state.exprValueStrs[index];
          }
          return "...";
        });
        if (this.props.markdown) {
          html = str ? markdown.toHTML(str) : "";

          // Make sure links are external
          html = html.replace(/<a href=/g, '<a target="_blank" href=');
          return R('div', {
            dangerouslySetInnerHTML: {
              __html: html
            }
          });
        } else {
          return R('span', null, str);
        }
      }
    }]);
    return TextExprsComponent;
  }(React.Component);

  ;

  TextExprsComponent.propTypes = {
    localizedStr: PropTypes.object, // String to render (localized)
    exprs: PropTypes.array, // Array of mwater-expressions to insert at {0}, {1}, etc.
    schema: PropTypes.object.isRequired, // Schema that includes the current form
    responseRow: PropTypes.object.isRequired, // response row to use
    locale: PropTypes.string, // locale (e.g. "en") to use
    markdown: PropTypes.bool // True to render as markdown text
  };

  return TextExprsComponent;
}.call(undefined);