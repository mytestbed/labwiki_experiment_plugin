map "/disconnect_all_db_connections" do
  handler = lambda do |env|
    LabWiki::Plugin::Experiment::Util.disconnect_all_db_connections
    [200, {}, ""]
  end
  run handler
end

map "/plugin/experiment/create_iwidget" do
  handler = lambda do |env|
    req = ::Rack::Request.new(env)
    LabWiki::Plugin::Experiment::IBookWidget.create_widget_zip(req)
  end
  run handler
end

