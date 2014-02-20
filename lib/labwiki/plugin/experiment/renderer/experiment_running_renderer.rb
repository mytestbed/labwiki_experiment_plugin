
require 'labwiki/plugin/experiment/renderer/experiment_common_renderer'

module LabWiki::Plugin::Experiment

  class ExperimentRunningRenderer < ExperimentCommonRenderer

    def render_content
      render_toolbar
      render_properties
      render_graphs
      render_logging

      props = (@experiment.exp_properties || []).to_json
      javascript %{
        require(['plugin/experiment/js/experiment_monitor', 'omf/data_source_repo'], function(experiment_monitor, ds) {
          #{@experiment.datasource_renderer};
          var r_#{object_id} = experiment_monitor('#{@experiment.name}', '#{@data_id}', '#{props}');
        })
      }

    end

    def render_toolbar
      div :class => 'widget-toolbar' do
        #if @experiment.state.to_s == 'running'
        button "Stop experiment", :id => 'btn-stop-experiment', :class => 'btn-stop-experiment btn btn-danger'
        #end
        button "Dump", :id => 'btn-dump', :exp_id => @experiment.name, :class => 'btn-dump btn btn-default'
        div :class => 'alert-dump', :style => "display: none; margin: 7px 0 7px 7px; padding: 5px;"
      end
    end

    def render_properties
      properties = @experiment.exp_properties
      #puts ">>>> #{properties}"
      render_header "Experiment Properties"
      div :class => 'experiment-status' do
        table :class => 'experiment-status table table-bordered', :style => 'width: auto'  do
          render_field_static :name => 'Name', :value => @experiment.name
          render_field_static :name => 'Status', :value => @experiment.state
          render_field_static :name => 'UUID', :value => @experiment.uuid
          surl = @experiment.url
          render_field_static :name => 'Script', value: surl, url: "lw:prepare/source_edit?url=#{surl}"
          if @experiment.slice
            render_field_static :name => 'Slice', :value => @experiment.slice
          end
        end
        topts = {
          id: "#{@data_id}_prop_table",
          class: 'experiment-properties table table-bordered',
          style: 'width: auto'
        }
        table topts do
          # if properties
            # properties.each_with_index do |prop, i|
              # prop[:index] = i
              # prop[:html_id] = "#{@data_id}_p_#{prop[:name]}"
              # render_field_static(prop, false)
            # end
          # end
        end
      end
    end

    def render_logging
      render_header  "Logging"
      div :class => 'experiment-log' do
        table :class => 'experiment-log table table-bordered'
        #div :class => 'experiment-log-latest'
      end
    end

    def render_graphs
      render_header  "Graphs"
      div :class => 'experiment-graphs' do
      end
    end

    def render_header(header_text)
      h3 do
        a :class => 'toggle', :href => '#'
        text header_text
      end
    end

  end # class
end # module
