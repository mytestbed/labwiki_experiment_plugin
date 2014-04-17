
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
            render_field -1, :name => 'Name', :size => 24, :default => @experiment.name

            geni_projs = OMF::Web::SessionStore[:projects, :geni_portal]
            if geni_projs && !geni_projs.empty? && LabWiki::Configurator[:gimi] && LabWiki::Configurator[:gimi][:ges]
              render_field(-1, name: 'Project', type: :select, options: geni_projs.map {|v| v[:name]})
              render_field(-1, name: 'Experiment_context', type: :select)
              render_field(-1, name: 'Slice', type: :select)
            else
              if LabWiki::Configurator[:plugins][:experiment][:ignore_slice]
                render_field(-1, name: 'Slice', type: :hidden, default: "default_slice")
              else
                render_field(-1, name: 'Slice', type: :text, default: "default_slice")
              end
            end

            render_field_static :name => 'Script', :value => @experiment.url, :url => "lw:prepare/source_edit?url=#{@experiment.url}"
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
        url: "lw:execute/experiment?url=#{@experiment.url}",
        script: @experiment.url,
        session_id: OMF::Web::SessionStore.session_id
      }

      if LabWiki::Configurator[:gimi] && LabWiki::Configurator[:gimi][:ges]
        opts[:geni_projects] = OMF::Web::SessionStore[:projects, :geni_portal]
        javascript %{
          var geni_projects = #{OMF::Web::SessionStore[:projects, :geni_portal].to_json};

          if (typeof(window.exp_list) === "undefined") {
            window.exp_list = new ExpListView();
          }

          window.exp_list.setElement($('select[name="propexperiment_context"]'));
          window.exp_list.setupExpSelect();
        }
      end

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
            render_field_static :name => 'Script', :value => @experiment.url
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
