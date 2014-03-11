require 'time'
require 'ruby_parser'
require 'omf_web'
require 'omf-web/content/repository'
#require 'omf_oml/table'
require 'omf-web/session_store'

require 'labwiki/plugin/experiment/oml_connector'

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
    DEF_MONITOR_INTERVAL = 5 # How frequently to check on Job Service

    attr_reader :name, :uuid, :state, :url, :slice, :decl_properties, :exp_properties, :session_context, :job_url

    def initialize(params, config_opts)
      debug "PARAMS: #{params}, CONFIG: #{config_opts}"

      case params[:mime_type]
      when "text/ruby"
        @state = :new
        @url = params[:url]
        if (@url)
          @oedl_script = OMF::Web::ContentRepository.read_content(@url, {})
          begin
            @decl_properties = parse_oedl_script(@oedl_script)
          rescue => ex
            warn "Parsing OEDL script '#{@url}' - #{ex}"
            @decl_properties = []
          end
        end
      else
        @name = params[:name]
        @state = :unknown
        @url = params[:url]
        @decl_properties = []
        _init_oml()
        _query_job_status(@url)
      end

      unless @job_service = config_opts[:job_service]
        raise "Missing configuration 'job_service"
      end

      @config_opts = config_opts
      @session_context = OMF::Web::SessionStore.session_context
    end

    def start_experiment(properties, slice, name, gimi_info = {})
      #puts "PROP - #{properties.inspect}"
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

      _init_oml()
      _schedule_job(name, properties, slice, gimi_info)

      @start_time = Time.now
    end

    def _schedule_job(name, properties, slice, gimi_info)
      job = {
        name: name,
      }
      job[:slice] = slice if slice
      job[:irods_path] = gimi_info[:irods_path]

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
        #puts ">> VALUE: #{value} - pv: #{prop[:value]} def: #{p[:default].inspect}"
        next unless value

        # TODO: Define a more robust way for identifying resource properties
        if name.start_with? 'res'
        # if false # TODO: Right now ignore resources
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

        # TODO: FOR DEBUGGING ONLY
        # @name = name
        # return @name

        @name += "#{name.gsub(/\W+/, '_')}-"
      end
      @name +=  ts
      @name.delete(' ')
      @name
    end

    def state=(state)
      @state = state
      send_status(:state, state)
    end

    def send_status(type, msg)
      @status_table << [type, msg]
    end

    def stop_experiment
      _stop_job
    end

    def _init_oml

      #status_schema = [[:time, :int], :phase, [:completion, :float], :message]
      status_schema = [:type, :message]
      @status_table = OmlConnector.create_oml_table('status', status_schema, self)


      @oml_connector = OmlConnector.new(self)
      # @log_adapter = LogAdapter.new(self)
      # @log_table = @log_adapter.log_table
    end


    def _post_job(job)
      body = JSON.pretty_generate(job)
      debug "JOB: #{body}"
      EM.defer do
        begin
          unless js = @config_opts[:job_service]
            raise "Missing configuration 'job_service"
          end
          req = Net::HTTP::Post.new(js[:path] || '/jobs?_level=1', {'Content-Type' =>'application/json'})
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
            debug "Job service reply: #{reply.inspect}"
            @uuid = reply["uuid"]
            send_status(:ex_prop, {uuid: @uuid})
            self.state = reply["status"]
            @job_url = reply["href"]
            oml_url = reply["oml_db"]
            @oml_connector.connect(oml_url)
            #_monitor_job(@uuid)
          end
        rescue => ex
          error "While posting job to job service - #{ex}"
          debug "While posting job to job service - \n\t#{ex.backtrace.join("\n\t")}"
        end
      end
    end

    def _stop_job
      if @job_url
        debug "SEND job stop request to #{@job_url}>>>"
        EM.synchrony do
          begin
            response = EM::HttpRequest.new(@job_url).post(body: JSON.pretty_generate({status: 'aborted'}),
                                                          head: { 'Content-Type' => 'application/json' })
          rescue => ex
            warn "Exception while stopping a job - #{ex}"
            debug "While stopping a job - \n\t#{ex.backtrace.join("\n\t")}"
          end
        end
      else
        warn "Job URL is missing for experiment #{@name}"
      end
    end

    def disconnect_db_connections
      @oml_connector.disconnect if @oml_connector
    end

    def _query_job_status(url)
      EventMachine.synchrony do
        begin
          resp = EventMachine::HttpRequest.new(url).get(query: {_level: 0})
          unless (rcode = resp.response_header.status) == 200
            warn "Job update failed (#{rcode})- #{resp.response}"
          else
            reply = JSON.parse(resp.response)
            self.state = reply["status"]
            @uuid = reply["uuid"]
            @job_url = reply["href"]
            send_status(:ex_prop, {uuid: @uuid})
            @oml_connector.connect(reply["oml_db"])
          end
        rescue => ex
          warn "Exception while searching job service - #{ex}"
        end
      end
    end

    def user
      OMF::Web::SessionStore[:id, :user] || 'unknown'
    end

    # As widgets are dynamically added, we need register datasources from within the
    # widget renderer.
    #
    def datasource_renderer
      js = []
      #lp = @log_proxy ||= OMF::Web::DataSourceProxy.for_source(:name => @log_table.name)[0]
      lp = @log_proxy ||= @oml_connector.log_adapter.data_source_proxy()
      js << lp.to_javascript()
      lp = @ec_proxy ||= @oml_connector.ec_adapter.data_source_proxy()
      js << lp.to_javascript()

      lp = @status_proxy ||= OMF::Web::DataSourceProxy.for_source(:name => @status_table.name)[0]
      js << lp.to_javascript()

      # TODO: What is this?????
      #js.gsub '/_update/', 'http://localhost:5000/_update/'

      js.join("\n")
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

        #puts "PARSE: #{sx}"
        ph = {}
        [:name, :default, :comment].each_with_index do |key, i|
          ph[key] = _parse_sex_string(sx[3 + i])
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

    def _parse_sex_string(sx)
      case sx[0]
      when :str
        return sx[1];
      when :lit
        #puts "LIT #{sx[1]}-#{sx[1].class}"
        return sx[1];
      end
      nil
    end
  end # class

end # module
