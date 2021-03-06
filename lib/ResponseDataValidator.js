'use strict';

var _regenerator = require('babel-runtime/regenerator');

var _regenerator2 = _interopRequireDefault(_regenerator);

var _asyncToGenerator2 = require('babel-runtime/helpers/asyncToGenerator');

var _asyncToGenerator3 = _interopRequireDefault(_asyncToGenerator2);

var _classCallCheck2 = require('babel-runtime/helpers/classCallCheck');

var _classCallCheck3 = _interopRequireDefault(_classCallCheck2);

var _createClass2 = require('babel-runtime/helpers/createClass');

var _createClass3 = _interopRequireDefault(_createClass2);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

var AnswerValidator, ResponseDataValidator, ValidationCompiler, formUtils;

AnswerValidator = require('./answers/AnswerValidator');

ValidationCompiler = require('./answers/ValidationCompiler');

formUtils = require('./formUtils');

// ResponseDataValidator checks whether the entire data is valid for a response
module.exports = ResponseDataValidator = function () {
  function ResponseDataValidator() {
    (0, _classCallCheck3.default)(this, ResponseDataValidator);
  }

  (0, _createClass3.default)(ResponseDataValidator, [{
    key: 'validate',

    // It returns null if everything is fine
    // It makes sure required questions are properly answered
    // It checks custom validations
    // It returns the id of the question that caused the error, the error and a message which is includes the error and question
    // e.g. { questionId: someid, error: true for required, message otherwise, message: complete message including question text }
    //     If the question causing the error is nested (like a Matrix), the questionId is separated by a .
    //     RosterMatrix   -> matrixId.index.columnId
    //     RosterGroup   -> rosterGroupId.index.questionId
    //     QuestionMatrix -> matrixId.itemId.columnId
    value: function validate(formDesign, visibilityStructure, data, schema, responseRow) {
      return this.validateParentItem(formDesign, visibilityStructure, data, schema, responseRow, "");
    }

    // Validates an parent row
    //   keyPrefix: the part before the row id in the visibility structure. For rosters

  }, {
    key: 'validateParentItem',
    value: function () {
      var _ref = (0, _asyncToGenerator3.default)( /*#__PURE__*/_regenerator2.default.mark(function _callee(parentItem, visibilityStructure, data, schema, responseRow, keyPrefix) {
        var answer, answerId, answerValidator, cellData, column, columnIndex, completedId, entry, error, i, index, item, j, k, key, l, len, len1, len2, len3, ref, ref1, ref2, ref3, ref4, ref5, result, rosterData, row, rowIndex, validationError;
        return _regenerator2.default.wrap(function _callee$(_context) {
          while (1) {
            switch (_context.prev = _context.next) {
              case 0:
                // Create validator
                answerValidator = new AnswerValidator(schema, responseRow);
                ref = parentItem.contents;
                // For each item
                i = 0, len = ref.length;

              case 3:
                if (!(i < len)) {
                  _context.next = 64;
                  break;
                }

                item = ref[i];
                // If not visible, ignore

                if (visibilityStructure['' + keyPrefix + item._id]) {
                  _context.next = 7;
                  break;
                }

                return _context.abrupt('continue', 61);

              case 7:
                if (!(item._type === "Section" || item._type === "Group")) {
                  _context.next = 13;
                  break;
                }

                _context.next = 10;
                return this.validateParentItem(item, visibilityStructure, data, schema, responseRow, keyPrefix);

              case 10:
                result = _context.sent;

                if (!(result != null)) {
                  _context.next = 13;
                  break;
                }

                return _context.abrupt('return', result);

              case 13:
                if (!((ref1 = item._type) === "RosterGroup" || ref1 === "RosterMatrix")) {
                  _context.next = 27;
                  break;
                }

                answerId = item.rosterId || item._id;
                rosterData = data[answerId] || [];
                index = j = 0, len1 = rosterData.length;

              case 17:
                if (!(j < len1)) {
                  _context.next = 27;
                  break;
                }

                entry = rosterData[index];
                // Key prefix is itemid.indexinroster.
                _context.next = 21;
                return this.validateParentItem(item, visibilityStructure, entry.data, schema, responseRow, '' + keyPrefix + answerId + '.' + index + '.');

              case 21:
                result = _context.sent;

                if (!(result != null)) {
                  _context.next = 24;
                  break;
                }

                return _context.abrupt('return', {
                  questionId: item._id + '.' + index + '.' + result.questionId,
                  error: result.error,
                  message: formUtils.localizeString(item.name) + (' (' + (index + 1) + ')') + result.message
                });

              case 24:
                index = ++j;
                _context.next = 17;
                break;

              case 27:
                if (!formUtils.isQuestion(item)) {
                  _context.next = 61;
                  break;
                }

                answer = data[item._id] || {};

                if (!(item._type === 'MatrixQuestion')) {
                  _context.next = 56;
                  break;
                }

                ref2 = item.items;
                rowIndex = k = 0, len2 = ref2.length;

              case 32:
                if (!(k < len2)) {
                  _context.next = 54;
                  break;
                }

                row = ref2[rowIndex];
                ref3 = item.columns;
                // For each column
                columnIndex = l = 0, len3 = ref3.length;

              case 36:
                if (!(l < len3)) {
                  _context.next = 51;
                  break;
                }

                column = ref3[columnIndex];
                key = row.id + '.' + column._id;
                completedId = item._id + '.' + key;
                cellData = (ref4 = answer.value) != null ? (ref5 = ref4[row.id]) != null ? ref5[column._id] : void 0 : void 0;

                if (!(column.required && (cellData != null ? cellData.value : void 0) == null || (cellData != null ? cellData.value : void 0) === '')) {
                  _context.next = 43;
                  break;
                }

                return _context.abrupt('return', {
                  questionId: completedId,
                  error: true,
                  message: formUtils.localizeString(item.text) + (' (' + (rowIndex + 1) + ') ') + formUtils.localizeString(column.text) + " is required"
                });

              case 43:
                if (!(column.validations && column.validations.length > 0)) {
                  _context.next = 48;
                  break;
                }

                validationError = new ValidationCompiler().compileValidations(column.validations)(cellData);

                if (!validationError) {
                  _context.next = 48;
                  break;
                }

                return _context.abrupt('return', {
                  questionId: completedId,
                  error: validationError,
                  message: formUtils.localizeString(item.text) + (' (' + (rowIndex + 1) + ')') + formUtils.localizeString(column.text) + (' ' + validationError)
                });

              case 48:
                columnIndex = ++l;
                _context.next = 36;
                break;

              case 51:
                rowIndex = ++k;
                _context.next = 32;
                break;

              case 54:
                _context.next = 61;
                break;

              case 56:
                _context.next = 58;
                return answerValidator.validate(item, answer);

              case 58:
                error = _context.sent;

                if (!(error != null)) {
                  _context.next = 61;
                  break;
                }

                return _context.abrupt('return', {
                  questionId: item._id,
                  error: error,
                  message: formUtils.localizeString(item.text) + " " + (error === true ? "is required" : error)
                });

              case 61:
                i++;
                _context.next = 3;
                break;

              case 64:
                return _context.abrupt('return', null);

              case 65:
              case 'end':
                return _context.stop();
            }
          }
        }, _callee, this);
      }));

      function validateParentItem(_x, _x2, _x3, _x4, _x5, _x6) {
        return _ref.apply(this, arguments);
      }

      return validateParentItem;
    }()
  }]);
  return ResponseDataValidator;
}();