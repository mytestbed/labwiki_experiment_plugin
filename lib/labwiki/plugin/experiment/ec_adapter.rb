require 'labwiki/plugin/experiment/graph_adapter'
require 'httparty'
require 'set'

module LabWiki::Plugin::Experiment

  # Monitors and processes the EC Metadata table which reports
  # primarily on changes to experiment properties.
  #
  #
  class EcAdapter < OMF::Base::LObject
    DEF_QUERY_INTERVAL = 3 # secs
    DEF_QUERY_LIMIT = 100

    attr_reader :ec_table, :data_source_proxy

    def initialize(experiment)
      super()
      @experiment = experiment

      schema = [:domain, :key, :value]
      @table = OmlConnector.create_table('ec', schema, experiment)
      _setup_ec_processor
      @data_source_proxy = OMF::Web::DataSourceProxy.for_source(:name => @table.name)[0]
      @resources_in_group = Set.new
      @resources_discovered = Set.new
     end

    def on_connected(connection)
      @connection = connection
      query = 'SELECT domain, key, value FROM omf_ec_meta_data ORDER BY oml_seq'
      opts = {}
      opts[:check_interval] = 10 unless @experiment.completed?
      connection.feed_table(@table, query, opts)


      # @connection = connection
      # #schema = OMF::OML::OmlSchema.new [:time, [:level, :integer], :logger, :data]
      # start_time = nil
      #
      # q = connection[:omf_ec_meta_data].select(:domain, :key, :value).order(:oml_seq)
      # offset = 0
      # handler = _row_processor
      # @t_q = LabWiki::Plugin::Experiment::Util::retry(DEF_QUERY_INTERVAL) do
      #   rows = q.limit(DEF_QUERY_LIMIT, offset).all
      #   disconnect if rows.empty? && @experiment.completed?
      #   offset += rows.size
      #   rows.each do |m|
      #     handler.call(m)
      #   end
      #   false # keep on going
      # end
    end

    def on_new_resource_discovered(res_name)
      @resources_discovered << res_name
      @table << ['resources', 'up', @resources_discovered.intersection(@resources_in_group).size.to_s]
    end

    def on_new_resource_in_group(res_name)
      @resources_in_group << res_name
      @table << ['resources', 'known', @resources_in_group.size.to_s]
    end

    def on_progress_message(msg)
      @table << ['progress', 'msg', msg]
    end

    def disconnect
      @t_q.cancel if @t_q
    end

    # Setup a filter on the table to check for updates on "sys/state"
    #
    def _setup_ec_processor
      schema = @table.schema
      @table.on_before_row_added do |row|
        puts ">>>EC #{row}"
        domain, key, value = row
        if domain == "sys" && key == "state"
          @experiment.state = value
          if @experiment.completed?
            EM.defer do
              begin
                v = JSON.parse(Net::HTTP.get(URI("#{@experiment.job_url}/verifications")))["verification"].first
                if v && v["href"]
                  r = JSON.parse(Net::HTTP.get(URI(v["href"])))["result"]

                  r.each do |k, v|
                    v = v.nil? ? "_undefined_" : v.to_s
                    @table << schema.hash_to_row(domain: "verify", key: k, value: v)
                  end
                end
              rescue => ex
                warn "Exception while querying a job - #{ex}"
                debug "While querying a job - \n\t#{ex.backtrace.join("\n\t")}"
              end
            end
          end
        end
        row
      end
    end

  end # class
end # module


