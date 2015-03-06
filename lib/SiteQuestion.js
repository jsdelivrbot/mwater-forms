var Question, SiteQuestion, siteCodes, _,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __hasProp = {}.hasOwnProperty;

Question = require('./Question');

siteCodes = require('./siteCodes');

_ = require('lodash');

module.exports = SiteQuestion = (function(_super) {
  __extends(SiteQuestion, _super);

  function SiteQuestion() {
    return SiteQuestion.__super__.constructor.apply(this, arguments);
  }

  SiteQuestion.prototype.renderAnswer = function(answerEl) {
    answerEl.html('<div class="input-group">\n  <input type="tel" class="form-control">\n  <span class="input-group-btn"><button class="btn btn-default" id="select" type="button">' + this.T("Select") + '</button></span>\n</div>\n<div class="text-muted">\n  <span id="site_type"></span> \n  <span id="site_name"></span>\n</div>');
    if (this.ctx.selectSite == null) {
      return this.$("#select").attr("disabled", "disabled");
    }
  };

  SiteQuestion.prototype.updateAnswer = function(answerEl) {
    var val;
    val = this.getAnswerValue();
    if (val) {
      val = val.code;
    }
    answerEl.find("input").val(val);
    this.$("#site_name").text("");
    this.$("#site_type").text("");
    if (this.ctx.getSite && val) {
      return this.ctx.getSite(val, (function(_this) {
        return function(site) {
          var type;
          if (site) {
            type = _.map(site.type, _this.T).join(" - ");
            _this.$("#site_name").text(site.name || "");
            return _this.$("#site_type").text(type + ": ");
          }
        };
      })(this));
    }
  };

  SiteQuestion.prototype.events = {
    'change': 'changed',
    'click #select': 'selectSite'
  };

  SiteQuestion.prototype.changed = function() {
    return this.setAnswerValue({
      code: this.$("input").val()
    });
  };

  SiteQuestion.prototype.selectSite = function() {
    return this.ctx.selectSite(this.options.siteTypes, (function(_this) {
      return function(siteCode) {
        return _this.setAnswerValue({
          code: siteCode
        });
      };
    })(this));
  };

  SiteQuestion.prototype.validateInternal = function() {
    if (!this.$("input").val()) {
      return false;
    }
    if (siteCodes.isValid(this.$("input").val())) {
      return false;
    }
    return "Invalid Site";
  };

  return SiteQuestion;

})(Question);