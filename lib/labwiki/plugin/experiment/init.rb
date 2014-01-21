
module LabWiki::Plugin
  module Experiment; end
end

require 'labwiki/plugin/experiment/experiment_widget'
require 'labwiki/plugin/experiment/renderer/experiment_setup_renderer'
require 'labwiki/plugin/experiment/renderer/experiment_running_renderer'

LabWiki::PluginManager.register :experiment, {
  :search => lambda do ||
  end,
  :selector => lambda do ||
  end,
  :on_session_init => lambda do
    #repo = OMF::Web::ContentRepository.register_repo(id, opts)
    #OMF::Web::SessionStore[:execute, :repos] << repo
    puts ">>>> EXPERIMENT NEW SESSION"
  end,
  :widgets => [
    {
      :name => 'experiment',
      :context => :execute,
      :priority => lambda do |opts|
        case opts[:mime_type]
        when /^text\/ruby/
          500
        when /^exp\/task/
          400
        else
          nil
        end
      end,
      :widget_class => LabWiki::Plugin::Experiment::ExperimentWidget,
      :search => lambda do |pat, opts|
        # TODO The next line should be commented out when upgrading to newest omf_web
        opts[:mime_type] = 'text/ruby'
        OMF::Web::ContentRepository.find_files(pat, opts)
      end
      # if col == 'execute' && OMF::Web::SessionStore[:exps, :omf]
        # res = []
        # OMF::Web::SessionStore[:exps, :omf].find_all do |v|
          # v[:id] =~ /#{pat}/
        # end.each { |v| res << { label: "task:#{v[:id]}", omf_exp_id: v[:id] } }
      # else
        # fs = OMF::Web::ContentRepository.find_files(pat, opts)
        # res = fs.collect do |f|
          # f[:label] = url = f.delete(:url)
          # f[:content] = Base64.encode64("#{f[:mime_type]}::#{url}").gsub("\n", '')
          # f
        # end
      # end

    }
  ],
  :renderers => {
    :experiment_setup_renderer => LabWiki::Plugin::Experiment::ExperimentSetupRenderer,
    :experiment_running_renderer => LabWiki::Plugin::Experiment::ExperimentRunningRenderer
  },
#  :resources => File.dirname(__FILE__) + File.SEPARATOR + 'resource'
  :resources => File.dirname(__FILE__) + '/resource' # should find a more portable solution
}

