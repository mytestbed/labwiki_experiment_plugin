
require 'labwiki/plugin/experiment/version'

require 'labwiki/plugin/experiment/experiment_widget'
require 'labwiki/plugin/experiment/renderer/experiment_setup_renderer'
require 'labwiki/plugin/experiment/renderer/experiment_running_renderer'
require 'labwiki/plugin/experiment/experiment_search_proxy'

LabWiki::PluginManager.register :experiment, {
  :version => LabWiki::Plugin::Experiment::VERSION,

  :selector => lambda do ||
  end,
  :on_session_init => lambda do
    #repo = OMF::Web::ContentRepository.register_repo(id, opts)
    #OMF::Web::SessionStore[:execute, :repos] << repo
    #puts ">>>> EXPERIMENT NEW SESSION"
  end,
  :widgets => [
    {
      :name => 'experiment',
      :context => :execute,
      :priority => lambda do |opts|
        case opts[:mime_type]
        when /^text\/ruby/
          500
        when /^plugin\/experiment/
          900
        else
          nil
        end
      end,
      :widget_class => LabWiki::Plugin::Experiment::ExperimentWidget,
      :search => lambda do |pat, opts, wopts|
        LabWiki::Plugin::Experiment::ExperimentSearchProxy.instance.find(pat, opts, wopts)
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
  :resources => File.join(File.dirname(__FILE__), 'resource'),
  :config_ru => File.join(File.dirname(__FILE__), 'config.ru'),
  :global_js => 'js/experiment_global.js'
}

