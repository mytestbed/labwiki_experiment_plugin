define(['theme/labwiki/js/labwiki'], function (LW) {

  var experiment_setup = function(form_id, opts) {
    var form_el = $('#' + form_id);

    function ctxt() {};

    form_el.find('.btn-start-experiment').click(function(event) {
      event.preventDefault();

      var params = {};
      _.each(form_el.serializeArray(), function(el) {
        if (el.value.length > 0) {
          params[el.name] = el.value;
        }
      });

      var copts = {
        action: 'start_experiment',
        col: 'execute',
        plugin: 'experiment',
        widget_id: opts.widget_id,
        sid: opts.session_id,
        paramaters: params
      };

      LW.execute_controller.refresh_content(copts, 'POST');
     });

    return ctxt;
  };

  return experiment_setup;
});
