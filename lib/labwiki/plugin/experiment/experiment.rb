require 'time'
require 'ruby_parser'
require 'omf_web'
require 'omf-web/content/repository'
require 'omf_oml/table'
# require 'labwiki/plugin/experiment/run_exp_controller'
require 'labwiki/plugin/experiment/oml_connector'
# require 'labwiki/plugin/experiment/graph_description'
# require 'labwiki/plugin/experiment/redis_helper'

# HACK to read data source from data source proxy, this should go to omf_web
# module OMF::Web
  # class DataSourceProxy < OMF::Base::LObject
    # attr_reader :data_source
  # end
# end

module LabWiki::Plugin::Experiment

  # Maintains the context for a particular experiment.
  #
  class Experiment < OMF::Base::LObject
    attr_reader :name, :state, :url, :slice, :decl_properties, :exp_properties

    def initialize(params, config_opts)
      debug "PARAMS: #{params}, CONFIG: #{config_opts}"

      @state = :new
      @url = params[:url]
      if (@url)
        @oedl_script = OMF::Web::ContentRepository.read_content(@url, {})
        @decl_properties = parse_oedl_script(@oedl_script)
      end

      @config_opts = config_opts
    end

    def start_experiment(properties, slice, name, irods = {})
      unless @state == :new
        warn "Attempt to start an already running or finished experiment"
        return # TODO: Raise appropriate exception
      end

      @slice = slice
      name = _create_name(name)
      @content_url = "exp:#{name}"
      # unless script_path = OMF::Web::ContentRepository.absolute_path_for(@url)
        # warn "Can't find script '#{url}'"
        # return # TODO: Raise appropriate exception
      # end
      info "Starting experiment name: '#{@name}' url: '#{@url}'"

      OMF::Web::SessionStore[:exps, :omf] ||= []
      #exp = { id: @name, instance: self }
      exp = { id: name }

      if irods
        exp[:irods_path] = irods[:path]
        exp[:exp_name] = irods[:exp_name]
      end
      OMF::Web::SessionStore[:exps, :omf] << exp

      _create_oml_tables()
      _schedule_job(name, properties, slice, irods)


      @start_time = Time.now
    end

    def _schedule_job(name, properties, slice, irods)
      job = {
        name: name,
      }
      job[:slice] = slice if slice

      unless @oedl_script
        raise "Don't have the oedl script content"
      end
      bc = Base64.encode64(Zlib::Deflate.deflate(@oedl_script))
      job[:oedl_script] = {
        type: "application/zip",
        encoding: "base64",
        content: bc.split("\n")
      }

      job[:ec_properties] = @exp_properties = ec_props = []
      props = {}
      properties.each {|p| props[p[:name]] = p }
      @decl_properties.each do |p|
        ep = {name: (name = p[:name])}
        prop = props[name]
        value = (prop ? prop[:value] : nil) || p[:default]
        next unless value

        # TODO: Define a more robust way for identifying resource properties
        if name.start_with? 'res'
          rname = (value == p[:default] ? nil : value) # ignore default values
          type = 'node'
          res = ep[:resource] = {type: type}
          res[:name] = rname if rname
        else
          ep[:value] = value
        end
        ec_props << ep
      end
      _post_job(job)
      self.state = :pending
    end

    def _create_name(name)
      ts = Time.now.iso8601.split('+')[0].gsub(':', '-')
      @name = "#{self.user}-"
      if (!name.nil? && name.to_s.strip.length > 0)
        @name += "#{name.gsub(/\W+/, '_')}-"
      end
      @name +=  ts
      @name.delete(' ')
      @name
    end

    def state=(state)
      @state = state
    end

    def stop_experiment()
      @state = :finished
      @ec.stop
      self.persist [:status]
      @oml_connector.disconnect
    end

    def _create_oml_tables
      @status_table = _create_oml_table('status', [[:time, :int], :phase, [:completion, :float], :message])
      @log_table = _create_oml_table('log', [[:time, :int], :severity, :path, :message])
      #@graph_table = _create_oml_table('graph', [:id, :description])
      #@oml_connector = OmlConnector.new(@name, @graph_table, @config_opts[:oml])
    end

    def _create_oml_table(tname, schema)
      if dsp = OMF::Web::DataSourceProxy.find("#{tname}_#{@name}", false)
        table = dsp.data_source
      else
        table = OMF::OML::OmlTable.new "#{tname}_#{@name}", schema
        OMF::Web::DataSourceProxy.register_datasource table rescue warn $!
      end
      table
    end

    def _post_job(job)
      body = JSON.pretty_generate(job)
      puts "JOB: #{body}"
      EM.defer do
        begin
          unless js = @config_opts[:job_service]
            raise "Missing configuration 'job_service"
          end
          req = Net::HTTP::Post.new(js[:path] || '/jobs', {'Content-Type' =>'application/json'})
          # #req.basic_auth @user, @pass
          req.body = body
          response = Net::HTTP.new(js[:host], js[:port] || 80).start {|http| http.request(req) }
          unless (rcode = response.code.to_i) == 200
            warn "Job request failed (#{rcode}::#{rcode.class})- #{response.body}"
            self.state = :failed
          else
            unless response.content_type == 'application/json'
              raise "Wrong content type ('#{response.content_type} for job service reply, expected 'application/json'."
            end
            body = response.body
            reply = JSON.parse(body)
            puts '-------'
            puts reply.inspect
            puts '-------'
            @uuid = reply["uuid"]
            @job_url = reply["href"]
            oml_url = reply["oml_db"]
            @oml_connector = OmlConnector.new(oml_url, @status_table, @log_table, self)
            self.state = reply["status"]
          end
        rescue => ex
          error "While posting job to job service - #{ex}"
          debug "While posting job to job service - \n\t#{ex.backtrace.join("\n\t")}"
        end
      end
    end

    def to_json
    end

    def user
      OMF::Web::SessionStore[:id, :user] || 'unknown'
    end

    def handle_exp_output(ec, etype, msg)
      begin
        debug "output:#{etype}: #{msg.inspect}"

        case etype
        when 'STARTED'
          info "Experiment #{@name} started. PID: #{ec.pid}"
          @state = :running
          self.persist [:status, :pid]
        when 'LOG'
          process_exp_log_msg(msg)
        when 'DONE.OK'
          @state = :finished
          self.persist [:status]
          @oml_connector.disconnect
        end
      rescue Exception => ex
        warn "EXCEPTION: #{ex}"
        debug ex.backtrace.join("\n")
      end
    end

    def process_exp_log_msg(msg)
      if (m = msg.match /^.*(INFO|WARN|ERROR|DEBUG|FATAL)\s+(.*)$/)
        severity = m[1].to_sym
        path = ''
        message = m[-1]
        return if message.start_with? '------'

        if (m = message.match(/^\s*REPORT:([A-Za-z:]*)\s*(.*)/))
          case m[1]
          when /START:/
            @gd = LabWiki::Plugin::Experiment::GraphDescription.new
          when /STOP/
            @oml_connector.add_graph(@gd)
            @gd = nil
          else
            @gd.parse(m[1], m[2])
          end
          return
        end

        log_msg_row = [Time.now - @start_time, severity, path, message]
        @log_table.add_row(log_msg_row)
      end
    end

    # As widgets are dynamically added, we need register datasources from within the
    # widget renderer.
    #
    def datasource_renderer
      lp = @log_proxy ||= OMF::Web::DataSourceProxy.for_source(:name => "log_#{@name}")[0]
      js = lp.to_javascript()

      #gp = @graph_proxy ||= OMF::Web::DataSourceProxy.for_source(:name => "graph_#{@name}")[0]
      #js += gp.to_javascript()


      # TODO: What is this?????
      js.gsub '/_update/', 'http://localhost:5000/_update/'
    end

    def parse_oedl_script(content)
      parser = RubyParser.new
      sexp = parser.process(content)
      # Looking for 'defProperty'
      properties = sexp.collect do |sx|
        #puts "SX: >>> #{sx}"
        next if sx.nil? || (sx.is_a? Symbol)
        next unless sx[0] == :call
        next unless sx[2] == :defProperty

        params = sx[3]
        #puts "PARSE: #{params}--#{sx}"
        #next unless params.is_a? Hash
        ph = {}
        [nil, :name, :default, :comment].each_with_index do |key, i|
          next unless (v = params[i]).is_a? Sexp
          ph[key] = v[1]
        end
        if ph.empty?
          warn "Wrong RubyParser version"
          ph = nil
        end
        ph
      end.compact

      debug "parse_oedl_script: #{properties.inspect}"
      properties
    end
  end # class

end # module
