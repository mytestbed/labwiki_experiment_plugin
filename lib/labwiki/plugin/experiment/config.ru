map "/disconnect_all_db_connections" do
  handler = lambda do |env|
    LabWiki::Plugin::Experiment::Util.disconnect_all_db_connections
    [200, {}, ""]
  end
  run handler
end
