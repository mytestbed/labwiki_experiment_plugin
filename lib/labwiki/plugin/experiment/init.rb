
require 'labwiki/plugin/experiment/experiment_widget'
require 'labwiki/plugin/experiment/renderer/experiment_setup_renderer'
require 'labwiki/plugin/experiment/renderer/experiment_running_renderer'
require 'labwiki/plugin/experiment/experiment_search_proxy'

require 'labwiki/plugin/experiment/ibook_widget'
require 'labwiki/plugin/experiment/renderer/iwidget_create_renderer'

LabWiki::PluginManager.register :experiment, {
  :version => LabWiki.plugin_version([2, 2, 'pre'], __FILE__),
  :selector => lambda do ||
  end,
  :on_session_init => lambda do
    #repo = OMF::Web::ContentRepository.register_repo(id, opts)
    #OMF::Web::SessionStore[:execute, :repos] << repo
    #puts ">>>> EXPERIMENT NEW SESSION"
  end,
  :on_session_close => lambda do
    LabWiki::Plugin::Experiment::Util.disconnect_all_db_connections
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
    }, {
      :name => 'iwidget',
      :context => :execute,
      :widget_class => LabWiki::Plugin::Experiment::IBookWidget,
    }
  ],
  :renderers => {
    :experiment_setup_renderer => LabWiki::Plugin::Experiment::ExperimentSetupRenderer,
    :experiment_running_renderer => LabWiki::Plugin::Experiment::ExperimentRunningRenderer,
    :iwidget_create_renderer => LabWiki::Plugin::Experiment::IWidgetCreateRenderer
  },
  :resources => File.join(File.dirname(__FILE__), 'resource'),
  :config_ru => File.join(File.dirname(__FILE__), 'config.ru'),
  :global_js => 'js/experiment_global.js'
}

