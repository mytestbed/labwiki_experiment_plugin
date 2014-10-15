
require 'labwiki/plugin/experiment/renderer/experiment_common_renderer'

module LabWiki::Plugin::Experiment

  class IWidgetCreateRenderer < ExperimentCommonRenderer

    def initialize(widget, opts = {})
      super widget, nil
    end

    def content
      link :href => '/resource/plugin/experiment/css/experiment.css', :rel => "stylesheet", :type => "text/css"
      link :href => '/resource/plugin/experiment/css/ibook_widget.css', :rel => "stylesheet", :type => "text/css"

      div :class => 'experiment-iwdget-container', :id => @data_id do
        div class: 'content experiment-description' do
          render_content
        end
        # div class: 'busy' do
        #   text 'BUSY'
        # end
      end
    end


    def render_content
      render_start_form
    end

    def title_info
      {
        img_src: '/resource/plugin/experiment/img/ibook-32.png',
        title: 'New iBook Widget',
        #sub_title: '????'
        widget_id: @data_id
      }
    end

    def render_start_form
      fid = "f#{self.object_id}"
      form :id => fid, :class => 'start-form' do
        table :class => 'iwidget-create experiment-setup', :style => 'width: auto' do
          render_field(-1, name: 'Name', size: 24, comment: 'Name of experiment')
          render_field(-1, name: 'Script', size: 24, comment: 'URL of experiment script (D&D)')
          render_field(-1, name: 'Host', size: 24, comment: 'Labwiki host to use')
          render_field(-1, name: 'Width', size: 4, default: 320, comment: 'Width of widget')
          render_field(-1, name: 'Height', size: 4, default: 240, comment: 'Height of widget')
          tr :class => "buttons" do
            td :colspan => 3 do
              button "Download iWidget", :class => 'btn btn-primary btn-download-iwidget', :type => "submit", :id => "#{fid}_downloadIWidget"
            end
          end
        end
        render_javascript(fid)
      end

    end

    def render_javascript(fid)
      opts = {
        widget_id: @widget.widget_id,
      }

      javascript %{
        require(['plugin/experiment/js/iwidget_create'], function(IWidgetCreate) {
          IWidgetCreate('#{fid}', #{opts.to_json});
        });
      }
    end

  end # class
end # module
