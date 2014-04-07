define(['theme/labwiki/js/labwiki', 'plugin/experiment/js/jquery.fileDownload'], function (LW) {

  var iwidget_create = function(form_id, opts) {
    var form_el = $('#' + form_id);

    function ctxt() {};

    form_el.find('.btn-download-iwidget').click(function(event) {
      event.preventDefault();

      var params = {};
      _.each(form_el.serializeArray(), function(el) {
        if (el.value.length > 0) {
          var name = el.name.replace(/^prop/, '');
          params[name] = el.value;
        }
      });

      var copts = {
        action: 'start_experiment',
        col: 'execute',
        plugin: 'experiment',
        widget_id: opts.widget_id,
        sid: opts.session_id,
        parameters: params
      };

      $.fileDownload('/plugin/experiment/create_iwidget', {
        httpMethod: "POST",
        data: copts
      }).done(function () {
          alert('File download a success!');
      })
      .fail(function () {
        alert('File download failed!');
      });

    });

    return ctxt;
  };

  return iwidget_create;
});
