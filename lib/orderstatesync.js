/* ===========================================================
# sphere-order-state-sync - v0.0.4
# ==============================================================
# Copyright (c) 2013 Hajo Eichler
# Licensed under the MIT license.
*/
var OrderStateSync, OrderSync, ProgressBar, Q, Rest, logentries, _;

_ = require('underscore')._;

Rest = require('sphere-node-connect').Rest;

OrderSync = require('sphere-node-sync').OrderSync;

ProgressBar = require('progress');

logentries = require('node-logentries');

Q = require('q');

OrderStateSync = (function() {
  function OrderStateSync(options) {
    this.options = options != null ? options : {};
    if (!this.options.config) {
      throw new Error('No configuration in options!');
    }
    this.sync = new OrderSync({
      config: this.options.config
    });
    if (this.options.logentries) {
      this.log = logentries.logger({
        token: this.options.logentries.token
      });
    }
  }

  OrderStateSync.prototype.elasticio = function(msg, cfg, cb, snapshot) {
    var ordersFrom;
    if (msg.body) {
      ordersFrom = msg.body.results;
      return this.run(ordersFrom, cb);
    } else {
      return this.returnResult(false, 'No data found in elastic.io msg!', cb);
    }
  };

  OrderStateSync.prototype.getOrders = function(rest) {
    var deferred;
    deferred = Q.defer();
    rest.GET("/orders?limit=0", function(error, response, body) {
      var orders;
      if (error) {
        return deferred.reject("Error on fetching orders: " + error);
      } else if (response.statusCode !== 200) {
        return deferred.reject(("Problem on fetching orders (status: " + response.statusCode + "): ") + body);
      } else {
        orders = JSON.parse(body).results;
        return deferred.resolve(orders);
      }
    });
    return deferred.promise;
  };

  OrderStateSync.prototype.run = function(ordersFrom, callback) {
    var _this = this;
    if (!_.isFunction(callback)) {
      throw new Error('Callback must be a function!');
    }
    return this.initMatcher(ordersFrom).then(function(fromIndex2toIndex) {
      if (_this.options.showProgress) {
        _this.bar = new ProgressBar('Updating order states [:bar] :percent done', {
          width: 50,
          total: _.size(fromIndex2toIndex)
        });
      }
      return _this.process(fromIndex2toIndex).then(function(msg) {
        return _this.returnResult(true, msg, callback);
      }).fail(function(msg) {
        return _this.returnResult(false, msg, callback);
      });
    }).fail(function(msg) {
      return _this.returnResult(false, msg, callback);
    });
  };

  OrderStateSync.prototype.returnResult = function(positiveFeedback, msg, callback) {
    var d, logLevel;
    if (this.options.showProgress) {
      this.bar.terminate();
    }
    d = {
      component: this.constructor.name,
      status: positiveFeedback,
      msg: msg
    };
    if (this.log) {
      logLevel = positiveFeedback ? 'info' : 'err';
      this.log.log(logLevel, d);
    }
    return callback(d);
  };

  OrderStateSync.prototype.initMatcher = function(ordersFrom) {
    var deferred,
      _this = this;
    this.ordersFrom = ordersFrom;
    deferred = Q.defer();
    this.getOrders(this.sync._rest).then(function(ordersTo) {
      var expoInfo, fromIndex2toIndex, i, j, oFrom, oTo, _i, _j, _k, _len, _len1, _len2, _ref, _ref1, _ref2;
      _this.ordersTo = ordersTo;
      fromIndex2toIndex = {};
      _ref = _this.ordersTo;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        oTo = _ref[i];
        if (!oTo.exportInfo) {
          continue;
        }
        _ref1 = oTo.exportInfo;
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          expoInfo = _ref1[_j];
          if (expoInfo.externalId) {
            _ref2 = _this.ordersFrom;
            for (j = _k = 0, _len2 = _ref2.length; _k < _len2; j = ++_k) {
              oFrom = _ref2[j];
              if (oFrom.id === expoInfo.externalId) {
                fromIndex2toIndex[j] = i;
              }
            }
          }
        }
      }
      return deferred.resolve(fromIndex2toIndex);
    }).fail(function(msg) {
      return deferred.reject(msg);
    });
    return deferred.promise;
  };

  OrderStateSync.prototype.process = function(fromIndex2toIndex) {
    var deferred, f, posts, t;
    deferred = Q.defer();
    if (_.size(fromIndex2toIndex) === 0) {
      deferred.resolve('Nothing to do.');
      return deferred.promise;
    }
    posts = [];
    for (f in fromIndex2toIndex) {
      t = fromIndex2toIndex[f];
      posts.push(this.update(this.ordersFrom[f], this.ordersTo[t]));
    }
    Q.all(posts).then(function(msg) {
      return deferred.resolve(msg);
    }).fail(function(msg) {
      return deferred.reject(msg);
    });
    return deferred.promise;
  };

  OrderStateSync.prototype.update = function(orderFrom, orderTo) {
    var deferred,
      _this = this;
    deferred = Q.defer();
    this.sync.buildActions(orderFrom, orderTo).update(function(error, response, body) {
      if (_this.options.showProgress && _this.bar) {
        _this.bar.tick();
      }
      if (error) {
        return deferred.reject('Error on updating order: ' + error);
      } else {
        if (response.statusCode === 200) {
          return deferred.resolve('Order state updated.');
        } else if (response.statusCode === 304) {
          return deferred.resolve('Order state update not necessary.');
        } else {
          return deferred.reject('Problem on updating order state (status: #{response.statusCode}): ' + body);
        }
      }
    });
    return deferred.promise;
  };

  return OrderStateSync;

})();

module.exports = OrderStateSync;
