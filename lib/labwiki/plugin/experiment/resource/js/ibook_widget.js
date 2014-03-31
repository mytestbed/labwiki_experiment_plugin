
var LW = null;

define('theme/labwiki/js/labwiki', [], function() {
  return LW;
});

function window_location_host() {
  return LW.window_location_host();
}

define([], function() {
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
  };

  ctxt.refresh_content = function(opts, type) {
    if (opts.sid) ctxt.session_id = opts.sid;
    if (!opts.iwidget) opts.iwidget = {};
    opts.iwidget.version = VERSION;
    $.ajax({
      url: cfg.url + cfg.path,
      data: opts,
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
      url: url,
      data: opts,
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



