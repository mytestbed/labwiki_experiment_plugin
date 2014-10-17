
var LW = null;

define('theme/labwiki/js/labwiki', [], function() {
  return LW;
});

require.config({
  shim: {
    'vendor/jquery-ui-1.10.4/js/jquery-ui-1.10.4.custom': {
      "deps": [ "vendor/jquery-ui-1.10.4/js/jquery-1.10.2" ]
    }
  }
});


// Global function to be used by data_source3 to derive the
// URL for it's websocket connection. Normally, window.location.host
// will return that, but in this case, the base file is loaded locally.
//
function window_location_host() {
  return LW.window_location_host();
}


define(['vendor/jquery-ui-1.10.4/js/jquery-ui-1.10.4.custom',
          'css!vendor/bootstrap/css/bootstrap',
          'css!theme/labwiki/css/labwiki'], function() {
  VERSION = '1.0';
  var cfg = null;

  function ctxt(cfg_) {
    cfg = cfg_;

    $(function() {
      load_content(cfg.url + cfg.path, cfg.opts, cfg.type);
    });
  };

  ctxt.execute_controller = ctxt; // There is only one controller we are trying to proxy
  ctxt.session_id = null;

  ctxt.add_toolbar_button = function() {
    // IGNORE for the moment
    return {enable: function() {}};
  };

  ctxt.refresh_content = function(opts, type) {
    if (opts.sid) ctxt.session_id = opts.sid;
    if (!opts.iwidget) opts.iwidget = {};
    opts.iwidget.version = VERSION;
    $.ajax({
      url: cfg.url + cfg.path + "?sid=" + opts.sid,
      data: JSON.stringify(opts),
      contentType: "application/json",
      type: type || 'GET'
    }).done(function(data) {
      try {
        var content = data.html
                        .replace(/="\/resource/g, '="' + WidgetConfig.url + '/resource')
                        ;
        //prepare_content($(data.html));
        $('body').html(content);
      } catch(err) {
        // TODO: Find a better way of conveying problem
        var s = printStackTrace({e: err});
        console.log(s);
      }
    }).error(function(self, type, msg) {
      var j = 0;
    })
    ;
  };

  ctxt.window_location_host = function() {
    return cfg.url.replace(/^.*\/\//, ''); // remove leading http*://
  };


  function load_content(url, opts, type) {
    if (opts.sid) ctxt.session_id = opts.sid;
    if (!opts.iwidget) opts.iwidget = {};
    opts.iwidget.version = VERSION;

    $.ajax({
      url: url + "?sid=" + opts.sid,
      data: JSON.stringify(opts),
      contentType: "application/json",
      type: type || 'GET'
    }).done(function(data) {
      try {
        var content = data.html.replace(/="\/resource/g, '="' + WidgetConfig.url + '/resource');
        $('body').html(content);
      } catch(err) {
        // TODO: Find a better way of conveying problem
        var s = printStackTrace({e: err});
        console.log(s);
      }
    }).error(function(self, type, msg) {
      var j = 0;
    })
    ;
  }

  //--- INIT ----


  return LW = ctxt;
});



