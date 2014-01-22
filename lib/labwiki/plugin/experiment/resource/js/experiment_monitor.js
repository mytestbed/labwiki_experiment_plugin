define(['js/data_source_repo'], function (data_source_repo) {


  var experiment_monitor = function(exp_name) {
    var current_event = null;
    var graphs = {};

    function ctxt() {};

    OHUB.bind('data_source.status_' + exp_name + '.changed', function(update) {
      var events = update.events;
    });


    OHUB.bind('data_source.log_' + exp_name + '.changed', function(ev) {
      var msgs = ev.data_source.rows(); //.events;
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
      $('table.experiment-log').html(html)
    });

    var embed = function(embed_container, options) {
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
      require('graph/js/' + type, function(graph) {
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

    var process_graph_announcements = function(gds) {
      _.each(gds.rows(), function(e) {
        var id = e[1];
        if (graphs[id]) return;

        var opts = JSON.parse(e[2]);


        // Create the datasources
        _.each(opts.data_sources, function(dsh) {
          var ds = OML.data_sources.register(dsh);
          // var ds = OML.data_sources.register(dsh.stream, null, dsh.schema, []);
          // if (dsh.update_interval) {
            // ds.is_dynamic(dsh.update_interval)
          // }
        });
        embed($('div.experiment-graphs'), opts);
      });
    };
    var gds = data_source_repo.lookup('graph_' + exp_name);
    process_graph_announcements(gds);
    OHUB.bind(gds.event_name, function(ev) {
      process_graph_announcements(ev.data_source);
    });

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