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

var ImageDisplayComponent,
    ImagePopupComponent,
    PropTypes,
    R,
    React,
    RotationAwareImageComponent,
    boundMethodCheck = function boundMethodCheck(instance, Constructor) {
  if (!(instance instanceof Constructor)) {
    throw new Error('Bound instance method accessed before binding');
  }
};

PropTypes = require('prop-types');

React = require('react');

R = React.createElement;

ImagePopupComponent = require('./ImagePopupComponent');

RotationAwareImageComponent = require('./RotationAwareImageComponent');

// Displays an image
module.exports = ImageDisplayComponent = function () {
  var ImageDisplayComponent = function (_React$Component) {
    (0, _inherits3.default)(ImageDisplayComponent, _React$Component);

    function ImageDisplayComponent(props) {
      (0, _classCallCheck3.default)(this, ImageDisplayComponent);

      var _this = (0, _possibleConstructorReturn3.default)(this, (ImageDisplayComponent.__proto__ || (0, _getPrototypeOf2.default)(ImageDisplayComponent)).call(this, props));

      _this.handleImgError = _this.handleImgError.bind(_this);
      _this.handleImgClick = _this.handleImgClick.bind(_this);
      _this.state = {
        error: false,
        url: null,
        popup: false
      };
      return _this;
    }

    (0, _createClass3.default)(ImageDisplayComponent, [{
      key: 'componentDidMount',
      value: function componentDidMount() {
        return this.update(this.props);
      }
    }, {
      key: 'componentWillReceiveProps',
      value: function componentWillReceiveProps(newProps) {
        return this.update(newProps);
      }
    }, {
      key: 'update',
      value: function update(props) {
        var _this2 = this;

        // Get URL of thumbnail
        return props.imageManager.getImageThumbnailUrl(props.image.id, function (url) {
          return _this2.setState({
            url: url,
            error: false
          });
        }, function () {
          return _this2.setState({
            error: true
          });
        });
      }
    }, {
      key: 'handleImgError',
      value: function handleImgError() {
        boundMethodCheck(this, ImageDisplayComponent);
        return this.setState({
          error: true
        });
      }
    }, {
      key: 'handleImgClick',
      value: function handleImgClick() {
        boundMethodCheck(this, ImageDisplayComponent);
        return this.setState({
          popup: true
        });
      }
    }, {
      key: 'render',
      value: function render() {
        var _this3 = this;

        var src;
        if (this.state.error) {
          src = "img/no-image-icon.jpg";
        } else if (this.state.url) {
          src = this.state.url;
        } else {
          src = "img/image-loading.png";
        }
        return R('span', null, React.createElement(RotationAwareImageComponent, {
          image: this.props.image,
          imageManager: this.props.imageManager,
          onClick: this.handleImgClick,
          height: 100,
          thumbnail: true
        }), this.state.popup ? React.createElement(ImagePopupComponent, {
          imageManager: this.props.imageManager,
          image: this.props.image,
          onClose: function onClose() {
            return _this3.setState({
              popup: false
            });
          },
          T: this.props.T
        }) : void 0);
      }
    }]);
    return ImageDisplayComponent;
  }(React.Component);

  ;

  ImageDisplayComponent.propTypes = {
    image: PropTypes.object.isRequired, // Image object to display
    imageManager: PropTypes.object.isRequired,
    T: PropTypes.func.isRequired
  };

  return ImageDisplayComponent;
}.call(undefined);