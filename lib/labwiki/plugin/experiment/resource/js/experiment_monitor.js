define(['omf/data_source_repo', 'theme/labwiki/js/labwiki'], function (data_source_repo, LW) {


  var experiment_monitor = function(exp_name, el_prefix, properties) {
    var current_event = null;
    var graphs = {};
    var status_msgs_processed = 0;
    var toolbar_buttons = {};

    function ctxt() {};

    function process_status_messages(evt) {
      //var ds = data_source_repo.lookup('exp_status_' + exp_name);
      var ds = evt.data_source;
      var msgs = ds.rows(); //.events;
      _.each(msgs.slice(status_msgs_processed), function(e) {
        switch (e[1]) {
          case 'state':
            process_state_message(e[2]);
            break;
          case 'graph':
            process_graph_announcement(e[2]);
            break;
          case 'ex_prop':
            process_ex_prop(e[2]);
            break;
          default:
            console.log("Don't know how to process '" + e[1] + "' status type");
        }
        status_msgs_processed += 1;
      });
      var i = 0;;

      // var gds = data_source_repo.lookup('graph_' + exp_name);
      // process_graph_announcements(gds);
      // OHUB.bind(gds.event_name, function(ev) {
        // process_graph_announcements(ev.data_source);
      // });

    }

    function process_state_message(msg) {
      // Display a badge in the sub title
      var sub_title = $('#' +  el_prefix + '_widget_sub_title');
      var label;
      switch (msg) {
        case 'pending': label = 'label-default">Pending'; break;
        case 'running': label = 'label-primary">Running'; break;
        case 'finished': label = 'label-success">Finished'; break;
        case 'failed': label = 'label-danger">Failed'; break;
        case 'aborted': label = 'label-danger">Aborted'; break;
      }
      if (label) {
        sub_title.html('<span class="label ' + label + '</span>');
      } else {
        console.log("WARN: Unknown state '" + msg + "'.");
      }

      // Display stop, dump button based on status
      toolbar_buttons.save.enable(msg == 'pending' || msg == 'running');
      toolbar_buttons.dump.enable(! (msg == 'pending' || msg == 'failed'));

      // Update status field in experiment properties
      var status = $('#' +  el_prefix + '_s_status');
      status.text(msg);
      status.removeClass('undefined').addClass('defined');
      status.parent().effect("highlight", {}, 2000);
    }

    function process_ex_prop(prop_list) {
      _.each(prop_list, function(v, k) {
        var ex_prop = $('#' +  el_prefix + '_s_' + k);
        ex_prop.text(v);
        ex_prop.parent().effect("highlight", {}, 2000);
      });
    }

    var ec_msgs_processed = 0;
    function process_ec_messages(ev) {
      var msgs = ev.data_source.rows();
      _.each(msgs.slice(ec_msgs_processed), function(e) {
        switch (e[1]) {
          case 'prop':
            process_prop_update(e[2], e[3]);
            break;
        }
        ec_msgs_processed += 1;
      });
    }

    var prop_templ = '<tr id="{id}">\
                        <td class="desc">{name}</td>\
                        <td class="input"><span class="{klass}" >{value}</span></td>\
                      </tr>';
    var properties = {};

    function process_prop_update(name, value) {
      if (properties[name] == value) return;

      properties[name] = value;
      id = el_prefix + '_p_' + name;
      s = {id: id, name: name,
           value: (value == '_undefined_') ? 'undefined' : "" + value,
           klass: (value == '_undefined_') ? 'undefined' : 'defined'
      };
      var html = prop_templ.replace(/{[^{}]+}/g, function(key) {
        return s[key.replace(/[{}]+/g, "")] || "";
      });
      var tr = $('#' + id);
      if (tr.length == 0) {
        var tbl = $('#' + el_prefix + '_prop_table');
        tbl.append(html);
      } else {
        tr.replaceWith(html);
      }
      var td = $('#' + id).find("td.input");
      td.effect("highlight", {}, 2000);
    }

    log_severity = [
      ['default', 'D'], ['primary', 'I'], ['warning', 'W'], ['danger', 'E']
    ];

    function update_log_table(evt) {
      //var ds = data_source_repo.lookup('exp_log_' + exp_name);
      var ds = evt.data_source;
      var msgs = ds.rows(); //.events;
      var l = msgs.length;
      if (l < 1 || current_event == msgs[l - 1]) return;

      var html = "";
      _.each(msgs.slice(0).reverse(), function(e) {
        var ts = e[1].toFixed(1);
        var severity = log_severity[e[2]];
        var message = e[4];

        html = html + '<tr><td>'
          + ts
          + '</td><td><span class="label label-' + severity[0] + '">' + severity[1]
          + '</span></td><td>' + message.replace(/</g, '&lt;')
          + '</td></tr>'
          ;
      });
      $('table.experiment-log').html(html);
    }

    function embed(embed_container, options, in_modal) {
      var opts = jQuery.extend(true, {}, options); // deep copy
      var type = opts.type;
      in_modal = in_modal == true;

      // Create a div to embed the graph in
      var eid =  'e' + Math.round((Math.random() * 10E12));
      var caption = options.caption || 'Caption Missing';
      embed_container
        .append('<div class="oml_' + type + '" id="w' + eid + '"></div>')
        //.append(cap_h)
        ;
      if (!in_modal) {
        var cap_h = '<div class="experiment-graph-caption">'
                  //+ '<a href="#" id="d' + id + '" class="ui-draggable">_</a>'
                  //+ '<div id="d' + id + '"><img src="/resource/plugin/experiment/img/graph_drag.png"></img></div>'
                  + '<img class="drag_icon" src="/resource/plugin/experiment/img/graph_drag.png" id="d' + eid + '"></img>'
                  + '<span class="experiment-graph-caption-figure">Figure:</span>'
                  + '<span class="experiment-graph-caption-text">' + caption + '</span>'
                  //+ '<img class="fullscreen_icon" src="/resource/vendor/glyphicons/png/glyphicons_349_fullscreen.png" id="f' + eid + '"></img>'
                  + '<span class="fullscreen_icon glyphicon glyphicon-fullscreen" id="f' + eid + '" />'
                  + '</div>'
                  ;

        embed_container.append(cap_h);
      }
      opts.base_el = '#w' + eid;
      //require(['/resource/graph/js/' + type + '.js'], function(graph) {
      require(['graph/' + type], function(graph) {
        //graphs[eid] = new OML[type](opts);
        var g = new graph(opts);
        //if (on_graph) on_graph(g);
      });

      if (in_modal) return;

      // Make Caption draggable
      var del = $('#d' + eid);
      //del.data('content', {mime_type: 'data/graph', opts: opts });
      del.data('content', function() { return graph_description(opts); });
      del.data('embedder', function(embed_container) {
        embed(embed_container, options);
      });
      del.draggable({
        appendTo: "body",
        helper: "clone",
        stack: 'body',
        zIndex: 9999
      });

      // Show figure full screen
      var fel = $('#f' + eid);
      fel.click(function() {
        var c = $('<div class="experiment-modal-graph"><div class="widget_container" /></div>');
        var graph = null;
        LW.show_modal(caption, c, function() {
          embed(c.find(".widget_container"), options, true);
        });
      });

    };

    function graph_description(gopts) {
      var d = {
        mime_type: 'data/graph',
        graph_type: gopts.type,
        caption: gopts.caption,
        mapping: gopts.mapping,
        axis: gopts.axis,
      };
      d.data_sources = _.map(gopts.data_sources, function(ds) {
        return {
          id: ds.id,
          name: ds.name,
          schema: _.map(ds.schema, function(v, k) {
            return v;
          }),
          context: ds.context,
          data_url: ds.data_url
        };
      });
      return d;
    }

    function process_graph_announcement(gd) {
      // Create the datasources
      _.each(gd.data_sources, function(dsh) {
        var ds = data_source_repo.register(dsh);
      });
      embed($('div.experiment-graphs'), gd);
    };

    /************** INIT ***********/

    var dsn = exp_name + "_" + LW.session_id;
    OHUB.bind('data_source.exp_log_' + dsn + '.changed', update_log_table);
    OHUB.bind('data_source.exp_status_' + dsn + '.changed', process_status_messages);
    OHUB.bind('data_source.exp_ec_' + dsn + '.changed', process_ec_messages);

    _.each(properties, function(p) {
      process_prop_update(name, value);
    });

    var sections = $('.widget_body h3 a.toggle');
    sections.click(function(ev) {
      var a = $(this);
      a.toggleClass('toggle-closed');
      var p = a.parent().next();
      p.slideToggle(400);
      return false;
    });

    var pc = LW.execute_controller;
    var b = toolbar_buttons;

    function handle_request_action_reply(reply) {
      if (reply.success != undefined) {
        $(".alert-toolbar").show();
        $(".alert-toolbar").html(reply.success).addClass("alert-success").removeClass("alert-danger");
      } else {
        $(".alert-toolbar").show();
        $(".alert-toolbar").html(reply.error).addClass("alert-danger").removeClass("alert-success");
      }
    };

    b.save = pc.add_toolbar_button({name: 'stop-experiment', awsome: 'stop', tooltip: 'Stop Experiment', active: true},
      function(ctxt) {
        ctxt.configure({awsome: 'spinner fa-spin', label: 'Stopping...'});
        var opts = {
          action: 'stop_experiment',
          col: 'execute'
        };

        LW.execute_controller.request_action(opts, 'POST', function(reply) {
          ctxt.configure({awsome: 'stop', active: false});
          handle_request_action_reply(reply);
        });
        return false;
      });

    b.dump = pc.add_toolbar_button({name: 'dump', awsome: 'download', tooltip: 'Database Dump', active: false},
      function(ctxt) {
        ctxt.configure({awsome: 'spinner fa-spin', label: 'Dumping...'});
        var opts = {
          action: 'dump',
          col: 'execute'
        };

        LW.execute_controller.request_action(opts, 'POST', function(reply) {
          ctxt.configure({awsome: 'download', active: false});
          if (reply.success != undefined) {
            window.open(reply.success, '_blank');
          } else {
            $(".alert-toolbar").show();
            $(".alert-toolbar").html(reply.error).addClass("alert-danger").removeClass("alert-success");
          }
          setTimeout(function() {
            $(".alert-toolbar").hide();
            ctxt.configure({awsome: 'download', active: true});
          }, 60000);
        });
        return false;
      });

    return ctxt;
  };

  return experiment_monitor;
});
