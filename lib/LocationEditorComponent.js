var $, H, LocationEditorComponent, LocationView, PropTypes, React, _,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

PropTypes = require('prop-types');

_ = require('lodash');

React = require('react');

H = React.DOM;

$ = require('jquery');

LocationView = require('./legacy/LocationView');

module.exports = LocationEditorComponent = (function(superClass) {
  extend(LocationEditorComponent, superClass);

  function LocationEditorComponent() {
    return LocationEditorComponent.__super__.constructor.apply(this, arguments);
  }

  LocationEditorComponent.propTypes = {
    location: PropTypes.object,
    locationFinder: PropTypes.object,
    onLocationChange: PropTypes.func,
    onUseMap: PropTypes.func,
    T: PropTypes.func
  };

  LocationEditorComponent.prototype.componentDidMount = function() {
    this.locationView = new LocationView({
      loc: this.props.location,
      hideMap: this.props.onUseMap == null,
      locationFinder: this.props.locationFinder,
      T: this.props.T
    });
    this.locationView.on('locationset', (function(_this) {
      return function(location) {
        return _this.props.onLocationChange(location);
      };
    })(this));
    this.locationView.on('map', (function(_this) {
      return function() {
        return _this.props.onUseMap();
      };
    })(this));
    return $(this.refs.main).append(this.locationView.el);
  };

  LocationEditorComponent.prototype.componentWillReceiveProps = function(nextProps) {
    if (!_.isEqual(nextProps.location, this.props.location)) {
      this.locationView.loc = nextProps.location;
      return this.locationView.render();
    }
  };

  LocationEditorComponent.prototype.componentWillUnmount = function() {
    return this.locationView.remove();
  };

  LocationEditorComponent.prototype.render = function() {
    return H.div({
      ref: "main"
    });
  };

  return LocationEditorComponent;

})(React.Component);
