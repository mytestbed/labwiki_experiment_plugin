require 'labwiki/column_widget'
require 'labwiki/plugin/experiment/experiment'

module LabWiki::Plugin::Experiment

  # Maintains the context for a particular experiment in this user context.
  #
  class ExperimentWidget < LabWiki::ColumnWidget

    attr_reader :name, :experiment

    def initialize(column, config_opts, unused)
      unless column == :execute
        raise "Should only be used in 'execute' column"
      end
      super column, :type => :experiment
      @experiment = nil

      @config_opts = config_opts

      LabWiki::Plugin::Experiment::Util.disconnect_all_db_connections

      OMF::Web::SessionStore[self.widget_id, :widgets] = self # Let's stick around a bit
    end

    def on_get_content(params, req)
      debug "on_get_content: '#{params.inspect}'"
      @experiment = LabWiki::Plugin::Experiment::Experiment.new(params, @config_opts)
      nil
    end

    def on_start_experiment(params, req)
      debug "START EXPERIMENT>>> #{params.inspect}"

      parameters = params[:parameters] || {}

      gimi_info = { irods_path: parameters.delete(:propexperiment_context) }
      slice = parameters.delete(:propslice)
      name = parameters.delete(:propname)
      # Left in parameters are exp properties
      @experiment.start_experiment(parameters, slice, name, gimi_info, params)
      nil
    end

    def on_stop_experiment(params, req)
      debug "STOP EXPERIMENT as requested>>> #{params.inspect}"
      @experiment.stop_experiment
    end

    def on_dump(params, req)
      debug "DUMP State as requested for Experiment #{@experiment.name}"
      @experiment.dump
    end

    def new?
      @experiment ? (@experiment.state == :new) : false
    end

    def content_renderer()
      debug "content_renderer: #{@opts.inspect}"
      if new?
        OMF::Web::Theme.require 'experiment_setup_renderer'
        ExperimentSetupRenderer.new(self, @experiment)
      else
        OMF::Web::Theme.require 'experiment_running_renderer'
        ExperimentRunningRenderer.new(self, @experiment)
      end
    end

    def mime_type
      'experiment'
    end

    def title
      @experiment ? (@experiment.name || 'NEW') : 'No Experiment'
    end

  end # class

end # module
