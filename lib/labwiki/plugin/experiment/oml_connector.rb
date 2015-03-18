#require 'eventmachine'
require 'em-synchrony'
#require 'sequel'
require 'em-pg-sequel'
require 'monitor'
require 'time'

require 'omf_oml/table'
require 'omf_oml/sql_source'
require 'labwiki/plugin/experiment/util'
require 'labwiki/plugin/experiment/log_adapter'
require 'labwiki/plugin/experiment/ec_adapter'

module LabWiki::Plugin::Experiment
  # Establishes a connection to the database associated with a
  # single experiment.
  #
  class OmlConnector < OMF::Base::LObject
    include MonitorMixin

    def self.create_table(tname, schema, experiment, clear_if_exists = true)
      name = experiment.name
      id = "exp_#{tname}_#{name}_#{OMF::Web::SessionStore.session_id}"
      if dsp = OMF::Web::DataSourceProxy.find(id, false)
        puts ">>> ALRADY EXISTS>>> #{id}"
        table = dsp.data_source
      else
        table = OMF::OML::OmlTable.new id, schema
        OMF::Web::DataSourceProxy.register_datasource table rescue warn $!
      end
      table
    end

    attr_reader :log_adapter, :ec_adapter
    attr_accessor :graph_adapters

    def initialize(experiment)
      super()
      @ec_adapter = EcAdapter.new(experiment)
      @log_adapter = LogAdapter.new(experiment, @ec_adapter)
      @experiment = experiment
      @graph_adapters = []

      @connected = false
      @periodic_timers = {}
    end

    def disconnect
      debug "Disconnecting #{@exp_id}...#{@connection}"
      # if connected?
      #   @connection.disconnect
      #   info "#{@exp_id} DB DISCONNECTED ...#{@connection}"
      #
      #   synchronize do
      #     @connected = false
      #   end
      # end
      # # Cancel timers
      # synchronize do
      #   @periodic_timers.each do |k, v|
      #     v.cancel
      #   end
      #   @periodic_timers.clear
      # end
      @log_adapter.disconnect
      @ec_adapter.disconnect
      @graph_adapters.each(&:stop)
    end

    def connected?
      @connected
    end

    def connect(db_uri)
      info "Attempting to connect to OML backend (DB) on '#{db_uri}'"
      @connection = OMF::OML::OmlSqlSource.create url: db_uri,
                                                  wait_for_database: 240,
                                                  wait_for_tables: 240
      @ec_adapter.on_connected(@connection)
      @log_adapter.on_connected(@connection)

      # #db_uri = "postgres://#{@config_opts[:user]}:#{@config_opts[:pwd]}@#{@config_opts[:host]}/#{exp_id}"
      # info "Attempting to connect to OML backend (DB) on '#{db_uri}'"
      # t_connect = LabWiki::Plugin::Experiment::Util::retry(10) do |hdl|
      #   begin
      #     connection = Sequel.connect(db_uri, pool_class: EM::PG::ConnectionPool, max_connections: 2)
      #
      #     synchronize do
      #       @connection = connection
      #       @connected = true
      #     end
      #     _on_connected(connection)
      #   rescue => e
      #     if e.message =~ /PG::.+FATAL:  database .+ does not exist/
      #       debug "Database '#{db_uri}' doesn't exist yet"
      #       # Experiment already finished, I won't look for DB any further
      #       hdl.done if @experiment.completed?
      #       next
      #     else
      #       error "Connection to OML backend (DB) failed - #{e}"
      #       debug e.backtrace.join("\n\t")
      #     end
      #   end
      #   hdl.done # done
      # end
      #
      # synchronize do
      #   @periodic_timers[:connect] = t_connect
      # end
    end

    def _on_connected(connection)
      debug "Connected to OML backend '#{@connection.url}'"

      @log_adapter.on_connected(connection)
      @ec_adapter.on_connected(connection)
    end
  end # class
end # module


