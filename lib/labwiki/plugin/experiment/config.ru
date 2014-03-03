map "/disconnect_all_db_connections" do
  handler = lambda do |env|
    LabWiki::Plugin::Experiment::Util.disconnect_all_db_connections
    [200, {}, ""]
  end
  run handler
end

map "/dump" do
  handler = lambda do |env|
    req = ::Rack::Request.new(env)
    omf_exp_id = req.params['domain']
    if LabWiki::Configurator[:gimi] && LabWiki::Configurator[:gimi][:dump_script]
      dump_cmd = File.expand_path(LabWiki::Configurator[:gimi][:dump_script])
    else
      return [500, {}, "Dump script not configured."]
    end

    job_service_cfg = LabWiki::Configurator[:plugins][:experiment][:job_service] rescue nil
    job_service_url = "#{job_service_cfg[:host]}:#{job_service_cfg[:port]}" rescue nil

    return [500, {}, "Job service not configured."] if job_service_url.nil?

    irods_path = HTTParty.get("http://#{job_service_url}/jobs/#{omf_exp_id}")["irods_path"]

    return [500, {}, "Cannot find iRODS path for experiment(task): #{omf_exp_id}"] if irods_path.nil?

    irods_web_url = "https://www.irods.org/web/browse.php#ruri=#{OMF::Web::SessionStore[:id, :irods_user]}.geniRenci@geni-gimi.renci.org:1247/geniRenci/home/gimiadmin/#{irods_path}"

    i_path = "#{irods_path}/#{LabWiki::Configurator[:gimi][:irods][:measurement_folder]}" rescue irods_path

    dump_cmd << " --domain #{omf_exp_id} --path #{i_path}"

    EM.popen(dump_cmd)
    [200, {}, "Dump script triggered and it will take a while. <br /> You could access the file via <a href='#{irods_web_url}' target='_blank'>iRODS web client</a>."]
  end
  run handler
end

