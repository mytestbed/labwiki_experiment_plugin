
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

