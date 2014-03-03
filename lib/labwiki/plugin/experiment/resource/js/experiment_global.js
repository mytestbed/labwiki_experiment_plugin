
/*
 * This script is loaded when LW starts up. It installs a few experiment
 * specific handlers.
 */

console.log(">>> EXPERIMENT GLOBAL is checking in");

window.addEventListener('beforeunload', function(e) {
  $.ajax({ async: false, url: "/disconnect_all_db_connections" });
});

LW.execute_controller.set_search_list_formatter('experiment', function(rec, i, type, def_formatter) {
  if (rec.mime_type != 'experiment') {
    return def_formatter(rec.name, rec.path, null, i, type);
  }

  var label;
  switch (rec.status) {
    case 'pending': label = 'label-default">Pending'; break;
    case 'running': label = 'label-primary">Running'; break;
    case 'finished': label = 'label-success">Finished'; break;
    case 'failed': label = 'label-danger">Failed'; break;
    case 'aborted': label = 'label-danger">Aborted'; break;
    default: label = 'label-error">' + rec.status ; break;
  }
  var sub_title = '<span class="label ' + label + '</span>';
  return def_formatter(rec.name, sub_title, 'plugin/experiment/img/experiment2-16.png', i, type);


});

