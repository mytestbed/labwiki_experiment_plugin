define(['omf/data_source_repo'], function (data_source_repo) {


  var experiment_monitor = function(exp_name) {
    var current_event = null;
    var graphs = {};
    var status_msgs_processed = 0;

    function ctxt() {};

    function process_status_messages() {
      var ds = data_source_repo.lookup('exp_status_' + exp_name);
      var msgs = ds.rows(); //.events;
      _.each(msgs.slice(status_msgs_processed), function(e) {
        switch (e[1]) {
          case 'state':
            process_state_event(e[2]);
            break;
          case 'graph':
            process_graph_announcement(e[2]);
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

    function process_state_event(msg) {

    }

    function update_log_table() {
      var ds = data_source_repo.lookup('exp_log_' + exp_name);
      var msgs = ds.rows(); //.events;
      var l = msgs.length;
      if (l < 1 || current_event == msgs[l - 1]) return;

      var html = "";
      _.each(msgs.slice(0).reverse(), function(e) {
        var ts = e[1].toFixed(1);
        var severity = e[2];
        var message = e[4];
        // Hack to hide stop exp button
        if (message.match(/^.*Experiment.*finished.*$/)) {
          $("#btn-stop-experiment").hide();
          $(".alert-dump").html(message).addClass("alert-success").removeClass("alert-error").show();
        }

        html = html + '<tr><td>'
          + ts
          + '</td><td><span class="label label-' + severity + '">' + severity
          + '</span></td><td>' + message
          + '</td></tr>'
          ;
      });
      $('table.experiment-log').html(html);
    }

    function embed(embed_container, options) {
      var opts = jQuery.extend(true, {}, options); // deep copy
      var type = opts.type;

      // Create a div to embed the graph in
      var eid =  'e' + Math.round((Math.random() * 10E12));
      var caption = options.caption || 'Caption Missing';
      var cap_h = '<div class="experiment-graph-caption">'
                //+ '<a href="#" id="d' + id + '" class="ui-draggable">_</a>'
                //+ '<div id="d' + id + '"><img src="/resource/plugin/experiment/img/graph_drag.png"></img></div>'
                + '<img src="/resource/plugin/experiment/img/graph_drag.png" id="d' + eid + '"></img>'
                + '<span class="experiment-graph-caption-figure">Figure:</span>'
                + '<span class="experiment-graph-caption-text">' + caption + '</span>'
                + '</div'
                ;
      embed_container
        .append('<div class="oml_' + type + '" id="w' + eid + '"></div>')
        .append(cap_h)
        ;
      opts.base_el = '#w' + eid;
      //require(['/resource/graph/js/' + type + '.js'], function(graph) {
      require(['graph/' + type], function(graph) {
        //graphs[eid] = new OML[type](opts);
        new graph(opts);
      });

      // Make Caption draggable
      var del = $('#d' + eid);
      del.data('content', {mime_type: 'data/graph', opts: opts });
      del.data('embedder', function(embed_container) {
        embed(embed_container, options);
      });
      del.draggable({
        appendTo: "body",
        helper: "clone",
        stack: 'body',
        zIndex: 9999
      });
    };

    function process_graph_announcement(gd) {
      // Create the datasources
      _.each(gd.data_sources, function(dsh) {
        var ds = data_source_repo.register(dsh);
      });
      embed($('div.experiment-graphs'), gd);
    };

    /************** INIT ***********/

    OHUB.bind('data_source.exp_log_' + exp_name + '.changed', update_log_table);
    OHUB.bind('data_source.exp_status_' + exp_name + '.changed', process_status_messages);


    var sections = $('.widget_body h3 a.toggle');
    sections.click(function(ev) {
      var a = $(this);
      a.toggleClass('toggle-closed');
      var p = a.parent().next();
      p.slideToggle(400);
      return false;
    });

    // STOP Experiment button
    $(".btn-stop-experiment").click(function(event) {
      $(this).attr('disabled', 'disabled');
      $(this).html('Stopping...');
      var opts = {
        action: 'stop_experiment',
        col: 'execute'
      };
      LW.execute_controller.refresh_content(opts, 'POST');
      return false;
    });

    // Hacking Dump button
    $("#btn-dump").click(function(event) {
      $(this).attr('disabled', 'disabled');
      $.post("/dump", { domain: $(this).attr("exp_id")}, function(data) {
        $(".alert-dump").html(data).addClass("alert-success").removeClass("alert-error");
      }).fail(function(data) {
        $(".alert-dump").html(data.responseText).addClass("alert-error").removeClass("alert-success");
      }).always(function(data) {
        $(".alert-dump").show();
      });
      setTimeout(function() {
        $(".alert-dump").hide();
        $("#btn-dump").removeAttr('disabled');
      }, 60000);
      return false;
    });

    return ctxt;
  };

  return experiment_monitor;
});
