
map "/dump" do
  handler = lambda do |env|
    req = ::Rack::Request.new(env)
    omf_exp_id = req.params['domain']
    if LabWiki::Configurator[:gimi] && LabWiki::Configurator[:gimi][:dump_script]
      dump_cmd = File.expand_path(LabWiki::Configurator[:gimi][:dump_script])
    else
      return [500, {}, "Dump script not configured."]
    end

    exp = nil
    OMF::Web::SessionStore.find_across_sessions do |content|
      content["omf:exps"] && (exp = content["omf:exps"].find { |v| v[:id] == omf_exp_id } )
    end

    if exp
      i_path = "#{exp[:irods_path]}/#{LabWiki::Configurator[:gimi][:irods][:measurement_folder]}" rescue "#{exp[:irods_path]}"

      dump_cmd << " --domain #{omf_exp_id} --path #{i_path}"
      EM.popen(dump_cmd)
      [200, {}, "Dump script triggered. <br /> Using command: #{dump_cmd} <br /> Unfortunately we cannot show you the progress."]
    else
      [500, {}, "Cannot find experiment(task) by domain id #{omf_exp_id}"]
    end
  end
  run handler
end

