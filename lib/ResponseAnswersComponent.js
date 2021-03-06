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

var AdminRegionDisplayComponent, AquagenxCBTDisplayComponent, AsyncLoadComponent, EntityDisplayComponent, ImageDisplayComponent, PropTypes, R, React, ResponseAnswersComponent, ResponseRow, VisibilityCalculator, _, ezlocalize, formUtils, moment, ui;

PropTypes = require('prop-types');

_ = require('lodash');

React = require('react');

R = React.createElement;

formUtils = require('./formUtils');

moment = require('moment');

ezlocalize = require('ez-localize');

ui = require('react-library/lib/bootstrap');

AsyncLoadComponent = require('react-library/lib/AsyncLoadComponent');

VisibilityCalculator = require('./VisibilityCalculator');

ResponseRow = require('./ResponseRow');

ImageDisplayComponent = require('./ImageDisplayComponent');

EntityDisplayComponent = require('./EntityDisplayComponent');

AdminRegionDisplayComponent = require('./AdminRegionDisplayComponent');

AquagenxCBTDisplayComponent = require('./answers/AquagenxCBTDisplayComponent');

// Displays the answers of a response in a table
module.exports = ResponseAnswersComponent = function () {
  var ResponseAnswersComponent = function (_AsyncLoadComponent) {
    (0, _inherits3.default)(ResponseAnswersComponent, _AsyncLoadComponent);

    function ResponseAnswersComponent() {
      (0, _classCallCheck3.default)(this, ResponseAnswersComponent);
      return (0, _possibleConstructorReturn3.default)(this, (ResponseAnswersComponent.__proto__ || (0, _getPrototypeOf2.default)(ResponseAnswersComponent)).apply(this, arguments));
    }

    (0, _createClass3.default)(ResponseAnswersComponent, [{
      key: 'isLoadNeeded',

      // Check if form design or data are different
      value: function isLoadNeeded(newProps, oldProps) {
        return !_.isEqual(newProps.formDesign, oldProps.formDesign) || !_.isEqual(newProps.data, oldProps.data);
      }

      // Call callback with state changes

    }, {
      key: 'load',
      value: function load(props, prevProps, callback) {
        var responseRow;
        responseRow = new ResponseRow({
          responseData: props.data,
          formDesign: props.formDesign,
          getEntityById: props.formCtx.getEntityById,
          getEntityByCode: props.formCtx.getEntityByCode
        });
        // Calculate visibility asynchronously
        return new VisibilityCalculator(props.formDesign, props.schema).createVisibilityStructure(props.data, responseRow, function (error, visibilityStructure) {
          return callback({
            error: error,
            visibilityStructure: visibilityStructure
          });
        });
      }
    }, {
      key: 'handleLocationClick',
      value: function handleLocationClick(location) {
        if (this.props.formCtx.displayMap) {
          return this.props.formCtx.displayMap(location);
        }
      }
    }, {
      key: 'renderLocation',
      value: function renderLocation(location) {
        if (location) {
          return R('div', null, R('a', {
            onClick: this.handleLocationClick.bind(this, location),
            style: {
              cursor: "pointer"
            }
          }, location.latitude + '\xB0 ' + location.longitude + '\xB0', location.accuracy ? '(+/-) ' + location.accuracy + ' m' : void 0));
        }
      }
    }, {
      key: 'renderAnswer',
      value: function renderAnswer(q, answer) {
        var _this2 = this;

        var choice, choiceId, code, entityType, i, item, label, len, ref, siteType, specify, target, units, unitsStr, valueStr;
        if (!answer) {
          return null;
        }
        // Handle alternates
        if (answer.alternate) {
          switch (answer.alternate) {
            case "na":
              return R('em', null, this.props.T("Not Applicable"));
            case "dontknow":
              return R('em', null, this.props.T("Don't Know"));
          }
        }
        if (answer.value == null) {
          return null;
        }
        switch (formUtils.getAnswerType(q)) {
          case "text":
            // Format as url if url
            if (answer.value && answer.value.match(/^((([A-Za-z]{3,9}:(?:\/\/)?)(?:[\-;:&=\+\$,\w]+@)?[A-Za-z0-9\.\-]+|(?:www\.|[\-;:&=\+\$,\w]+@)[A-Za-z0-9\.\-]+)((?:\/[\+~%\/\.\w\-_]*)?\??(?:[\-\+=&;%@\.\w_]*)#?(?:[\.\!\/\\\w]*))?)$/)) {
              // Open in system window if in cordova
              target = window.cordova != null ? "_system" : "_blank";
              return R('a', {
                href: answer.value,
                target: target
              }, answer.value);
            }
            return answer.value;
          case "number":
            return "" + answer.value;
          case "choice":
            choice = _.findWhere(q.choices, {
              id: answer.value
            });
            if (choice) {
              label = formUtils.localizeString(choice.label, this.props.locale);
              if (answer.specify != null) {
                specify = answer.specify[answer.value];
              } else {
                specify = null;
              }
              return R('div', null, label, specify ? (": ", R('em', null, specify)) : void 0);
            } else {
              return R('span', {
                className: "label label-danger"
              }, "Invalid Choice");
            }
            break;
          case "choices":
            return _.map(answer.value, function (v) {
              choice = _.findWhere(q.choices, {
                id: v
              });
              if (choice) {
                return R('div', null, formUtils.localizeString(choice.label, _this2.props.locale), answer.specify != null && answer.specify[v] ? (": ", R('em', null, answer.specify[v])) : void 0);
              } else {
                return R('div', {
                  className: "label label-danger"
                }, "Invalid Choice");
              }
            });
          case "date":
            // Depends on precision
            if (answer.value.length <= 7) {
              // YYYY or YYYY-MM
              return R('div', null, answer.value);
            } else if (answer.value.length <= 10) {
              // Date
              return R('div', null, moment(answer.value).format("LL"));
            } else {
              return R('div', null, moment(answer.value).format("LLL"));
            }
            break;
          case "units":
            if (answer.value && answer.value.quantity != null && answer.value.units != null) {
              // Find units
              units = _.findWhere(q.units, {
                id: answer.value.units
              });
              valueStr = "" + answer.value.quantity;
              unitsStr = units ? formUtils.localizeString(units.label, this.props.locale) : "(Invalid)";
              if (q.unitsPosition === "prefix") {
                return R('div', null, R('em', null, unitsStr), " ", valueStr);
              } else {
                return R('div', null, valueStr, " ", R('em', null, unitsStr));
              }
            }
            break;
          case "boolean":
            if (answer.value) {
              return this.props.T("True");
            } else {
              return this.props.T("False");
            }
          case "location":
            return this.renderLocation(answer.value);
          case "image":
            if (answer.value) {
              return R(ImageDisplayComponent, {
                image: answer.value,
                imageManager: this.props.formCtx.imageManager,
                T: this.props.T
              });
            }
            break;
          case "images":
            return _.map(answer.value, function (img) {
              return R(ImageDisplayComponent, {
                image: img,
                imageManager: _this2.props.formCtx.imageManager,
                T: _this2.props.T
              });
            });
          case "texts":
            return _.map(answer.value, function (txt) {
              return R('div', null, txt);
            });
          case "site":
            code = answer.value;
            // TODO Eventually always go to code parameter. Legacy responses used code directly as value.
            if (_.isObject(code)) {
              code = code.code;
            }
            // Convert to new entity type
            siteType = (q.siteTypes ? q.siteTypes[0] : void 0) || "Water point";
            entityType = siteType.toLowerCase().replace(new RegExp(' ', 'g'), "_");
            return R(EntityDisplayComponent, {
              entityCode: code,
              entityType: entityType,
              getEntityByCode: this.props.formCtx.getEntityByCode,
              renderEntityView: this.props.formCtx.renderEntitySummaryView,
              T: this.props.T
            });
          case "entity":
            return R(EntityDisplayComponent, {
              entityId: answer.value,
              entityType: q.entityType,
              getEntityById: this.props.formCtx.getEntityById,
              renderEntityView: this.props.formCtx.renderEntitySummaryView,
              T: this.props.T
            });
          case "admin_region":
            return R(AdminRegionDisplayComponent, {
              getAdminRegionPath: this.props.formCtx.getAdminRegionPath,
              value: answer.value,
              T: this.props.T
            });
          case "items_choices":
            ref = q.items;
            for (i = 0, len = ref.length; i < len; i++) {
              item = ref[i];
              choiceId = answer.value[item.id];
              if (choiceId != null) {
                choice = _.findWhere(q.choices, {
                  id: choiceId
                });
                if (choice != null) {
                  return R('div', null, formUtils.localizeString(choice.label, this.props.locale));
                } else {
                  return R('span', {
                    className: "label label-danger"
                  }, "Invalid Choice");
                }
              }
            }
            break;
          case "aquagenx_cbt":
            return R(AquagenxCBTDisplayComponent, {
              value: answer.value,
              questionId: q._id,
              imageManager: this.props.formCtx.imageManager
            });
        }
      }

      // Special render on multiple rows

    }, {
      key: 'renderMatrixAnswer',
      value: function renderMatrixAnswer(q, answer, prevAnswer) {
        var choice, choiceId, contents, i, item, itemTd, len, ref;
        if (!answer) {
          return null;
        }
        if (answer.alternate) {
          return null;
        }
        if (answer.value == null) {
          return null;
        }
        if (formUtils.getAnswerType(q) === "items_choices") {
          contents = [];
          ref = q.items;
          for (i = 0, len = ref.length; i < len; i++) {
            item = ref[i];
            itemTd = R('td', {
              style: {
                textAlign: "center"
              }
            }, formUtils.localizeString(item.label, this.props.locale));
            choiceId = answer.value[item.id];
            if (choiceId != null) {
              choice = _.findWhere(q.choices, {
                id: choiceId
              });
              if (choice != null) {
                contents.push(R('tr', null, itemTd, R('td', null, formUtils.localizeString(choice.label, this.props.locale))));
              } else {
                contents.push(R('tr', null, itemTd, R('td', null, R('span', {
                  className: "label label-danger"
                }, "Invalid Choice"))));
              }
              if (this.props.showPrevAnswers && prevAnswer) {
                choiceId = prevAnswer.value[item.id];
                if (choiceId != null) {
                  choice = _.findWhere(q.choices, {
                    id: choiceId
                  });
                  if (choice != null) {
                    contents.push(R('tr', null, itemTd, R('td', null, formUtils.localizeString(choice.label, this.props.locale))));
                  } else {
                    contents.push(R('tr', null, itemTd, R('td', null, R('span', {
                      className: "label label-danger"
                    }, "Invalid Choice"))));
                  }
                }
              }
            }
          }
          return contents;
        } else {
          return null;
        }
      }
    }, {
      key: 'renderQuestion',
      value: function renderQuestion(q, dataId) {
        var answer, dataIds, matrixAnswer, prevAnswer, prevRosterData, ref, ref1, rosterData, trProps;
        // Get answer
        dataIds = dataId.split('.');
        if (dataIds.length === 1) {
          answer = this.props.data[dataId];
        } else {
          rosterData = this.props.data[dataIds[0]];
          if (rosterData.value != null) {
            rosterData = rosterData.value;
            answer = rosterData[dataIds[1]][dataIds[2]];
          } else {
            answer = rosterData[dataIds[1]].data[dataIds[2]];
          }
        }
        // Do not display if empty and hide empty true
        if (this.props.hideEmptyAnswers && (answer != null ? answer.value : void 0) == null && !(answer != null ? answer.alternate : void 0)) {
          return null;
        }
        prevAnswer = null;
        trProps = {
          key: dataId
        };
        if (this.props.prevData) {
          if (dataIds.length === 1) {
            prevAnswer = this.props.prevData.data[dataId];
          } else {
            prevRosterData = this.props.prevData.data[dataIds[0]];
            if (prevRosterData != null) {
              if (prevRosterData.value != null) {
                prevRosterData = prevRosterData.value;
                prevAnswer = (ref = prevRosterData[dataIds[1]]) != null ? ref[dataIds[2]] : void 0;
              } else {
                prevAnswer = (ref1 = prevRosterData[dataIds[1]]) != null ? ref1.data[dataIds[2]] : void 0;
              }
            }
          }
        }
        matrixAnswer = this.renderMatrixAnswer(q, answer, prevAnswer);
        // If both answer and previous answer are falsy
        if (!prevAnswer && (answer != null ? answer.value : void 0) == null && this.props.hideUnchangedAnswers) {
          return null;
        }
        if (!_.isEqual(prevAnswer != null ? prevAnswer.value : void 0, answer != null ? answer.value : void 0) || !_.isEqual(prevAnswer != null ? prevAnswer.specify : void 0, answer != null ? answer.specify : void 0)) {
          if (this.props.highlightChanges) {
            trProps['style'] = {
              background: '#ffd'
            };
          }
        } else {
          if (this.props.hideUnchangedAnswers) {
            return null;
          }
        }
        return [R('tr', trProps, R('td', {
          key: "name",
          style: {
            width: "50%"
          }
        }, formUtils.localizeString(q.text, this.props.locale)), R('td', {
          key: "value"
        }, R('div', null, matrixAnswer == null ? this.renderAnswer(q, answer) : void 0, answer && answer.timestamp ? (this.props.T('Answered'), ": ", moment(answer.timestamp).format('llll')) : void 0, answer && answer.location ? this.renderLocation(answer.location) : void 0, prevAnswer != null && !_.isEqual(prevAnswer.value, answer != null ? answer.value : void 0) && this.props.showChangedLink ? R('a', {
          style: {
            float: 'right',
            display: 'inline-block',
            cursor: 'pointer',
            fontSize: 9
          },
          onClick: this.props.onChangedLinkClick,
          key: 'view_change'
        }, R(ui.Icon, {
          id: "glyphicon-pencil"
        }), " ", T("Edited")) : void 0)), this.props.showPrevAnswers && this.props.prevData ? R('td', {
          key: "prevValue"
        }, prevAnswer != null && !_.isEqual(prevAnswer.value, answer != null ? answer.value : void 0) && this.props.onCompleteHistoryLinkClick ? R('a', {
          style: {
            float: 'right',
            display: 'inline-block',
            cursor: 'pointer',
            fontSize: 9
          },
          onClick: this.props.onCompleteHistoryLinkClick,
          key: 'view_history'
        }, T("Show Changes")) : void 0, typeof prevMatrixAnswer === "undefined" || prevMatrixAnswer === null ? this.renderAnswer(q, prevAnswer) : void 0, prevAnswer && prevAnswer.timestamp ? R('div', null, this.props.T('Answered'), ": ", moment(prevAnswer.timestamp).format('llll')) : void 0, prevAnswer && prevAnswer.location ? this.renderLocation(prevAnswer.location) : void 0) : void 0), matrixAnswer];
      }

      // Add all the items with the proper rosterId to items array
      // Looks inside groups and sections

    }, {
      key: 'collectItemsReferencingRoster',
      value: function collectItemsReferencingRoster(items, contents, rosterId) {
        var i, len, otherItem, results;
        // Get the contents of all the other question that are referencing this roster
        results = [];
        for (i = 0, len = contents.length; i < len; i++) {
          otherItem = contents[i];
          if (otherItem._type === 'Group' || otherItem._type === 'Section') {
            this.collectItemsReferencingRoster(items, otherItem.contents, rosterId);
          }
          if (otherItem.rosterId === rosterId) {
            results.push(items.push.apply(items, otherItem.contents));
          } else {
            results.push(void 0);
          }
        }
        return results;
      }
    }, {
      key: 'renderItem',
      value: function renderItem(item, visibilityStructure, dataId) {
        var _this3 = this;

        var answer, colspan, column, contents, data, entry, i, index, itemValue, items, j, len, len1, ref, ref1, referencedRoster, rowItem, rows;
        if (!visibilityStructure[dataId]) {
          return;
        }
        colspan = this.props.showPrevAnswers && this.props.prevData ? 3 : 2;
        // Sections and Groups behave the same
        if (item._type === "Section" || item._type === "Group") {
          contents = _.map(item.contents, function (item) {
            return _this3.renderItem(item, visibilityStructure, item._id);
          });
          // Remove nulls
          contents = _.compact(contents);
          // Do not display if empty
          if (contents.length === 0) {
            return null;
          }
          return [R('tr', {
            key: item._id
          }, R('td', {
            colSpan: colspan,
            style: {
              fontWeight: "bold"
            }
          }, formUtils.localizeString(item.name, this.props.locale))), contents];
        }
        // RosterMatrices and RosterGroups behave the same
        // Only the one storing the data will display it
        // The rosters referencing another one will display a simple text to say so
        if (item._type === "RosterMatrix" || item._type === "RosterGroup") {
          items = [];
          // Simply display a text referencing the other roster if a reference
          if (item.rosterId != null) {
            // Unless hiding empty, in which case blank
            if (this.props.hideEmptyAnswers) {
              return null;
            }
            referencedRoster = formUtils.findItem(this.props.formDesign, item.rosterId);
            return R('tr', null, R('td', {
              style: {
                fontWeight: "bold"
              }
            }, formUtils.localizeString(item.name, this.props.locale)), R('td', {
              colSpan: colspan - 1
            }, R('span', {
              style: {
                fontStyle: 'italic'
              }
            }, this.props.T("Data is stored in {0}", formUtils.localizeString(referencedRoster.name, this.props.locale)))));
          }
          // Get the data for that roster
          data = this.props.data[item._id];
          if ((!data || data.length === 0) && this.props.hideEmptyAnswers) {
            return null;
          }
          // Get the questions of the other rosters referencing this one
          items = _.clone(item.contents);
          this.collectItemsReferencingRoster(items, this.props.formDesign.contents, item._id);
          return [R('tr', {
            key: item._id
          }, R('td', {
            colSpan: colspan,
            style: {
              fontWeight: "bold"
            }
          }, formUtils.localizeString(item.name, this.props.locale))), function () {
            var _this4 = this;

            var i, len, results;
            if (data != null) {
              // For each entry in data
              results = [];
              for (index = i = 0, len = data.length; i < len; index = ++i) {
                entry = data[index];
                contents = _.map(items, function (childItem) {
                  dataId = item._id + '.' + index + '.' + childItem._id;
                  return _this4.renderItem(childItem, visibilityStructure, dataId);
                });
                // Remove nulls
                contents = _.compact(contents);
                // Do not display if empty
                if (contents.length === 0) {
                  results.push(null);
                } else {
                  results.push([
                  // Display the index of the answer
                  R('tr', null, R('td', {
                    colSpan: colspan,
                    style: {
                      fontWeight: "bold"
                    }
                  }, index + 1 + '.')),
                  // And the answer for each question
                  contents]);
                }
              }
              return results;
            }
          }.call(this)];
        }
        if (item._type === "MatrixQuestion") {
          answer = this.props.data[dataId];
          if ((answer != null ? answer.value : void 0) != null) {
            rows = [];
            rows.push(R('tr', {
              key: item._id
            }, R('td', {
              colSpan: colspan,
              style: {
                fontWeight: "bold"
              }
            }, formUtils.localizeString(item.name, this.props.locale))));
            ref = item.items;
            for (i = 0, len = ref.length; i < len; i++) {
              rowItem = ref[i];
              itemValue = answer.value[rowItem.id];
              if (itemValue) {
                rows.push(R('tr', null, R('td', {
                  colSpan: colspan,
                  style: {
                    fontStyle: 'italic'
                  }
                }, formUtils.localizeString(rowItem.label, this.props.locale))));
                ref1 = item.columns;
                for (j = 0, len1 = ref1.length; j < len1; j++) {
                  column = ref1[j];
                  if (itemValue[column._id]) {
                    dataId = item._id + '.' + rowItem.id + '.' + column._id;
                    rows.push(this.renderItem(column, visibilityStructure, dataId));
                  }
                }
              }
            }
            return rows;
          } else {
            return null;
          }
        }
        if (formUtils.isQuestion(item)) {
          return this.renderQuestion(item, dataId);
        }
      }
    }, {
      key: 'render',
      value: function render() {
        var _this5 = this;

        if (this.state.error) {
          return R('div', {
            className: "alert alert-danger"
          }, this.state.error.message);
        }
        if (!this.state.visibilityStructure) {
          return R('div', null, "Loading...");
        }
        return R('table', {
          className: "table table-bordered table-condensed",
          style: {
            marginBottom: 0
          }
        }, R('thead', null, R('tr', null, R('th', null, "Question"), R('th', null, "Answer"), this.props.showPrevAnswers ? R('th', null, "Original Answer") : void 0)), R('tbody', null, _.map(this.props.formDesign.contents, function (item) {
          return _this5.renderItem(item, _this5.state.visibilityStructure, item._id);
        })));
      }
    }]);
    return ResponseAnswersComponent;
  }(AsyncLoadComponent);

  ;

  ResponseAnswersComponent.propTypes = {
    formDesign: PropTypes.object.isRequired,
    data: PropTypes.object.isRequired,
    schema: PropTypes.object.isRequired, // Schema of the 
    hideEmptyAnswers: PropTypes.bool, // True to hide empty answers
    locale: PropTypes.string, // Defaults to english
    T: PropTypes.func.isRequired, // Localizer to use
    formCtx: PropTypes.object.isRequired, // Form context to use
    prevData: PropTypes.object, // Previous data
    showPrevAnswers: PropTypes.bool,
    highlightChanges: PropTypes.bool,
    hideUnchangedAnswers: PropTypes.bool,
    showChangedLink: PropTypes.bool,
    onChangedLinkClick: PropTypes.func,
    onCompleteHistoryLinkClick: PropTypes.func
  };

  return ResponseAnswersComponent;
}.call(undefined);