require 'labwiki/plugin/experiment/graph_adapter'

module LabWiki::Plugin::Experiment

  # Monitors and processes the LOG table
  #
  class EcAdapter < OMF::Base::LObject
    DEF_QUERY_INTERVAL = 3 # secs
    DEF_QUERY_LIMIT = 100

    attr_reader :ec_table, :data_source_proxy

    def initialize(experiment)
      super()
      @experiment = experiment

      schema = [:domain, :key, :value]
      @table = OmlConnector.create_oml_table('ec', schema, experiment)
      @data_source_proxy = OMF::Web::DataSourceProxy.for_source(:name => @table.name)[0]
    end

    def on_connected(connection)
      @connection = connection
      #schema = OMF::OML::OmlSchema.new [:time, [:level, :integer], :logger, :data]
      start_time = nil

      q = connection[:omf_ec_meta_data].select(:domain, :key, :value)
      offset = 0
      handler = _row_processor
      @t_q = LabWiki::Plugin::Experiment::Util::retry(DEF_QUERY_INTERVAL) do
        q.limit(DEF_QUERY_LIMIT, offset).each do |m|
          handler.call(m)
          offset += 1
        end
        false # keep on going
      end
    end

    # Returns a lambda to be called for every incoming record
    # Primary function is to filter out graph descriptions and pass on the
    # rest to the ec_table so it can be processed by the UI
    #
    def _row_processor
      schema = @table.schema
      lambda do |rec|
        puts rec.inspect
        if rec[:domain] == "sys" && rec[:key] == "state"
          @experiment.state = rec[:value]
        end
        @table << schema.hash_to_row(rec)
      end
    end

    # def handle_exp_output(ec, etype, msg)
      # begin
        # debug "output:#{etype}: #{msg.inspect}"
#
        # case etype
        # when 'STARTED'
          # info "Experiment #{@name} started. PID: #{ec.pid}"
          # @state = :running
          # self.persist [:status, :pid]
        # when 'LOG'
          # process_exp_log_msg(msg)
        # when 'DONE.OK'
          # @state = :finished
          # self.persist [:status]
          # @oml_connector.disconnect
        # end
      # rescue Exception => ex
        # warn "EXCEPTION: #{ex}"
        # debug ex.backtrace.join("\n")
      # end
    # end

  end # class
end # module


