require 'labwiki/column_widget'
require 'zip'

module LabWiki::Plugin::Experiment

  # Maintains the context for a particular experiment in this user context.
  #
  class IBookWidget < LabWiki::ColumnWidget
    renderer :iwidget_create_renderer

    def self.create_widget_zip(req)
      args = req.params['parameters']
      debug "parameters: #{args.inspect}"
      name = args['name']
      host = args['host']
      url = args['script']
      width = args['width'] || '440'
      height = args['height'] || '800'
      unless host && url
        # 422 ... https://tools.ietf.org/html/rfc4918#page-78
        return [422, {'Content-Type' => 'application/json'}, {error: "Missing parameters 'host', or 'url'"}.to_json]
      end

      file_name, content = _build_wdgt_foder(name, host, url, width, height)
      content_length = content.bytesize
      debug "Downloading '#{file_name}' containing #{content_length} bytes"
      headers = {
        'Content-Disposition' => "attachment; filename=#{file_name}",
        'Content-Length' => "#{content_length}",
        'Content-Type' => 'application/zip',
        'Set-Cookie' => 'fileDownload=true; path=/' # required by jquery.fileDownload plugin
      }
      [200, headers, content]
    end

    def self._build_wdgt_foder(name, host, url, width, height)
      top_dir = File.join(File.dirname(__FILE__), '../../../..')
      tmpl_dir = File.join(top_dir, 'iwidget')

      Dir.mktmpdir do |wdgt_top_dir|
        wdgt_name = (name || url.gsub(/[_:\.\/]/, '_')) + '.wdgt'
        wdgt_dir = File.join(wdgt_top_dir, wdgt_name)
        debug "Creating '#{wdgt_name}' in '#{wdgt_dir}'"
        FileUtils.cp_r tmpl_dir, wdgt_dir

        config_in = File.join(tmpl_dir, 'config.js.in')
        unless File.readable?(config_in)
          abort "Can't find template file '#{config_in}'."
        end
        tmpl = File.read(config_in)
        s = tmpl.gsub('%HOST%', host.strip).gsub('%URL%', url.strip).gsub('%WIDTH%', width.strip).gsub('%HEIGHT%', height.strip)
        File.open(File.join(wdgt_dir, 'config.js'), 'w') do |f|
          f.write(s)
        end

        zip_name = wdgt_dir + '.zip'
        Zip::File.open(zip_name, Zip::File::CREATE) do |zipfile|
          offset = wdgt_top_dir.length + 1
          Dir[File.join(wdgt_dir, '**', '**')].each do |file|
            zipfile.add(file[offset .. -1], file)
          end
        end
        return [wdgt_name + '.zip', File.read(zip_name)]
      end
    end

    def initialize(column, config_opts, unused)
      unless column == :execute
        raise "Should only be used in 'execute' column"
      end
      super column, :type => :iwidget
      @config_opts = config_opts
      @title = 'New iBook Widget'
    end

    # def on_new_iwidget(params, req)
    #   # nothing to do really
    # end
    #
    # def content_renderer()
    #   'iwidget_create_renderer'
    # end

    # def mime_type
      # 'experiment/iwidget'
    # end
  end # class

end # module
