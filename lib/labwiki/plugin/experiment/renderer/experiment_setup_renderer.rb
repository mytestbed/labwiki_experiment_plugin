
require 'labwiki/plugin/experiment/renderer/experiment_common_renderer'

module LabWiki::Plugin::Experiment

  class ExperimentSetupRenderer < ExperimentCommonRenderer

    def render_content
      render_start_form
    end

    def render_start_form
      fid = "f#{self.object_id}"
      properties = @experiment.decl_properties
      form :id => fid, :class => 'start-form' do
        if properties
          table :class => 'experiment-setup', :style => 'width: auto' do
            render_field -1, :name => 'Name', :size => 24, :comment => "Experiment name", :default => @experiment.name

            projects = OMF::Web::SessionStore[:projects, :user]
            if projects && !projects.empty?
              render_field(-1, name: 'Project', field_type: :select,
                           options: projects.map {|v| v[:name]},
                           selected: projects.find { |p| p[:uuid].to_s == OMF::Web::SessionStore[:current_project, :user].to_s }.try(:[], :name))
            end

            slices = OMF::Web::SessionStore[:slices, :user]
            if slices && !slices.empty?
              render_field(-1, name: 'Slice', field_type: :select,
                           options: {}.tap { |hash| slices.each { |v| hash[v["name"]] = v["slice_urn"] } } )
            else
              render_field(-1, name: 'Slice', field_type: :text, default: "default_slice")
            end

            render_field_static :name => 'Script', :value => @experiment.oedl_url, :url => "lw:prepare:#{@experiment.oedl_url}"

            properties.each_with_index do |prop, i|
              render_field(-1, prop)
            end

            tr :class => "buttons" do
              td :colspan => 3 do
                button "Start Experiment", :class => 'btn btn-primary btn-start-experiment', :type => "submit", :id => "#{fid}_startExperiment"
              end
            end
          end
        end
        render_javascript(fid)
      end

    end

    def render_javascript(fid)
      opts = {
        properties: @experiment.decl_properties,
        widget_id: @widget.widget_id,
        #url: "lw:execute/experiment?url=#{@experiment.url}",
        #script: @experiment.url,
        session_id: OMF::Web::SessionStore.session_id
      }

      javascript %{
        require(['plugin/experiment/js/experiment_setup'], function(ExperimentSetup) {
          ExperimentSetup('#{fid}', #{opts.to_json});
        });
      }
    end

    def render_properties
      properties = @experiment.decl_properties
      div :class => 'experiment-status' do
        if properties
          table :class => 'experiment-status', :style => 'width: auto'  do
            render_field_static :name => 'Name', :value => @experiment.name
            render_field_static :name => 'Script', :value => @experiment.oedl_url
            properties.each_with_index do |prop, i|
              prop[:index] = i
              render_field_static(prop)
            end
          end
        end
      end
    end


  end # class
end # module
