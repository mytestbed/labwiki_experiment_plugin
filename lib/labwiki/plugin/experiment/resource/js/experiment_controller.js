define([], function () {

  var experiment_controller = function(opts) {

    function ctxt() {};

    ctxt.submit = function(form_el, fopts ) {
      function get_value(name, def_value) {
        var e = form_el.find('td.' + name).children();
        var v = e.val();
        if (v == "") v = e.text();
        if (v == "") v = def_value;
        return v;
      }

      var opts = {
        action: 'start_experiment',
        col: 'execute',
        widget_id: fopts.widget_id,
        name: get_value('propName', fopts.name),
        script: fopts.script,
        slice: get_value('propSlice', fopts.slice),
        irods_path: get_value('propexperiment_context')
      };

      opts.properties = _.compact(_.map(fopts.properties, function(prop, index) {
        var val = get_value('prop' + index, prop['default']);
        if (val == null) return null;
        return {name: prop.name, value: val};
      }));

      LW.execute_controller.refresh_content(opts, 'POST');
    };

    return ctxt;
  };

  return experiment_controller;
});
