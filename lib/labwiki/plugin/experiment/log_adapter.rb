require 'labwiki/plugin/experiment/graph_adapter'

module LabWiki::Plugin::Experiment

  # Monitors and processes the LOG table
  #
  class LogAdapter < OMF::Base::LObject
    # How often to check for log messages
    DEF_QUERY_INTERVAL = 5 # secs
    DEF_QUERY_LIMIT = 100

    # How many log messages to display.
    # Coordinate with experiment_monitor.js#update_log
    DEF_LOG_HISTORY = 50

    attr_reader :log_table, :data_source_proxy

    def initialize(experiment, ec_adapter)
      super()
      @experiment = experiment
      @ec_adapter = ec_adapter

      log_schema = [[:time, :text], [:level, :int32], :logger, :data]
      @log_table = OmlConnector.create_table('log', log_schema, experiment)
      @log_table.max_size = DEF_LOG_HISTORY
      _setup_log_processor
      @data_source_proxy = OMF::Web::DataSourceProxy.for_source(:name => @log_table.name)[0]
    end

    def on_connected(connection)
      @connection = connection
      query = 'SELECT time, level, logger, data FROM omf_ec_log WHERE level > 0'
      # Can't skip beginning of logs as that's where the graphs are defined
      #opts = {offset: -1 * DEF_LOG_HISTORY}
      opts = {}
      opts[:check_interval] = DEF_QUERY_INTERVAL unless @experiment.completed?
      connection.feed_table(@log_table, query, opts)
      #
      # schema = @log_table.schema
      # schema = OMF::OML::OmlSchema.new [:time, [:level, :integer], :logger, :data]
      # start_time = nil
      #
      # q = connection[:omf_ec_log].select(:time, :level, :logger, :data).where('level > 0')
      # offset = 0
      # handler = _log_processor
      # @t_q = LabWiki::Plugin::Experiment::Util::retry(DEF_QUERY_INTERVAL) do
      #   rows = q.limit(DEF_QUERY_LIMIT, offset).all
      #   disconnect if rows.empty? && @experiment.completed?
      #   offset += rows.size
      #   rows.each do |m|
      #     row = schema.hash_to_row(m)
      #     ts = Time.parse(row[0])
      #     start_time ||= ts
      #     row[0] = ts - start_time
      #     handler.call(row)
      #   end
      #   false # keep on going
      # end
    end

    def disconnect
      #@t_q.cancel if @t_q
    end

    # Setup a filter on the table to filter out graph descriptions and pass on the
    # rest to the log_table so it can be displyed on the UI
    #
    def _setup_log_processor
      gd = nil # 'gd' alone doesn't seem to work. Strange as it should be within the closure
      start_time = nil
      @log_table.on_before_row_added do |row|
        time = row[0]
        unless start_time
          start_time = Time.parse(time)
          debug "Setting log start time to #{start_time}"
        end
        dtime = (Time.parse(time) - start_time).to_i
        #puts ">>DTIME #{dtime} - #{Time.parse(time)} - #{row}"
        dtime = 0 if dtime < 0
        sec = dtime % 60
        min = (dtime / 60).to_i
        row[0] = sprintf "%i:%02i", min, sec

        #puts "LOG PROCESSOR(#{gd}): #{row.inspect}"

        message = row[3]
        if (m = message.match(/^REPORT:([A-Za-z:]*)\s*(.*)/))
          puts ">>> MESSAGE: #{message}"
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
          next nil
        elsif (m = message.match /Configure '(.*?)' to join/)
          @ec_adapter.on_new_resource_in_group(m[1])
        elsif (m = message.match /Newly discovered resource >> .*frcp.(.*)/)
          rname = m[1].split('/')[-1]
          @ec_adapter.on_new_resource_discovered(rname)
        elsif (m = message.match /[-]{3,}\s*(.*)/) # Step comments starting with at least 3 ---
          @ec_adapter.on_progress_message(m[1])
        end
        row
      end
    end
  end # class
end # module


