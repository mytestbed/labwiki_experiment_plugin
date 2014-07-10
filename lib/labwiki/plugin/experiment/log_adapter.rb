require 'labwiki/plugin/experiment/graph_adapter'

module LabWiki::Plugin::Experiment

  # Monitors and processes the LOG table
  #
  class LogAdapter < OMF::Base::LObject
    DEF_QUERY_INTERVAL = 3 # secs
    DEF_QUERY_LIMIT = 100

    attr_reader :log_table, :data_source_proxy

    def initialize(experiment)
      super()
      @experiment = experiment

      log_schema = [[:time, :int32], [:level, :int32], :logger, :data]
      @log_table = OmlConnector.create_oml_table('log', log_schema, experiment)
      @data_source_proxy = OMF::Web::DataSourceProxy.for_source(:name => @log_table.name)[0]
    end

    def on_connected(connection)
      @connection = connection
      schema = @log_table.schema
      schema = OMF::OML::OmlSchema.new [:time, [:level, :integer], :logger, :data]
      start_time = nil

      q = connection[:omf_ec_log].select(:time, :level, :logger, :data).where('level > 0')
      offset = 0
      handler = _log_processor
      @t_q = LabWiki::Plugin::Experiment::Util::retry(DEF_QUERY_INTERVAL) do
        rows = q.limit(DEF_QUERY_LIMIT, offset).all
        disconnect if rows.empty? && @experiment.completed?
        offset += rows.size
        rows.each do |m|
          row = schema.hash_to_row(m)
          ts = Time.parse(row[0])
          start_time ||= ts
          row[0] = ts - start_time
          handler.call(row)
        end
        false # keep on going
      end
    end

    def disconnect
      @t_q.cancel if @t_q
    end

    # Returns a lambda to be called for every incoming log message
    # Primary function is to filter out graph descriptions and pass on the
    # rest to the log_table so it can be displyed on the UI
    #
    def _log_processor
      gd = nil # 'gd' alone doesn't seem to work. Strange as it should be within the closure
      lambda do |row|
        #puts row.inspect

        message = row[3]
        if (m = message.match(/^REPORT:([A-Za-z:]*)\s*(.*)/))
          case m[1]
          when /START:/
            error "Unfinished graph description detected - #{gd}" if gd
            gd = LabWiki::Plugin::Experiment::GraphAdapter.new(m[2], @experiment, @connection)
          when /STOP/
            gd.start
            gd = nil
          else
            gd.parse(m[1], m[2])
          end
          next # Do not put graph description messages into the visible log
        end

        @log_table << row
      end
    end
  end # class
end # module


