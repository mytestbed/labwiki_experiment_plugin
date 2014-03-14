
require 'uri'
require 'omf_oml/schema'

module LabWiki::Plugin::Experiment

  # Hold the description for a graph defined for an experiment
  #
  class GraphAdapter < OMF::Base::LObject
    include MonitorMixin

    DEF_QUERY_INTERVAL = 3 # secs
    DEF_QUERY_LIMIT = 1000

    CLASS2TYPE = {
      Fixnum => 'int32',
      Float => 'double',
      String => 'string'
    }

    attr_reader :name, :type, :mstreams

    def initialize(graph_name, experiment, connection)
      super()
      @graph_name = graph_name
      @experiment = experiment
      @connection = connection
      @tables = {}
      @mstreams = {}
      @opts = {
        :margin => {:left => 80, :right => 50}
      }
      @periodic_timers = {}
    end

    def parse(type, descr)
      type = type.split(':')
      descr = URI.decode(descr)

      debug "parse: #{type}--#{descr}"
      case type[0]
      # when 'START'
        # @graph_name = descr
      when 'TYPE'
        @opts[:type] = descr
      when 'POSTFIX'
        @opts[:postfix] = descr
      when 'CAPTION'
        @opts[:caption] = descr
      when 'MS'
        @mstreams[type[1]] = descr
      when 'MAPPING'
        @opts[:mapping] = JSON.parse(descr)
      when 'AXIS'
        @opts[:axis] = JSON.parse(descr)
      # when 'STOP'
        # # ignore
      else
        warn("Unknown graph description type '#{type.inspect}'")
      end
    end

    def start
      @mstreams.each {|name, query| @tables[name] = {query: query}}
      @mstreams.each do |name, query|
        _discover_schema(name, query)
      end
    end

    def _discover_schema(name, query)
      debug "Initializing mstream '#{name}' (#{query})"

      row = @connection.fetch(query).first
      debug "First row to discover schema for '#{name}': #{row.inspect} - #{row.class}"
      schema = row.map do |k, v|
        unless type = CLASS2TYPE[v.class]
          warn "Unknown type mapping for class '#{v.class}'"
          type = :string
        end
        [k.to_sym, type]
      end
      table = nil
      @experiment.session_context.call do
        table = OmlConnector.create_oml_table("#{name}_#{object_id}", schema, @experiment)
      end
      #puts "TABLE>>> #{table}"
      _report_table name, table
    end

    def _report_table(name, table)
      synchronize do
        @tables[name][:table] = table
        ds = OMF::Web::DataSourceProxy.for_source(name: table.name)[0]
        @tables[name][:data_source] = ds

        # Now check if we already have all the required tables created
        @tables.values.each do |t|
          return unless t[:table]
        end
      end
      # OK, we now know all the schemas
      dss = @tables.map do |tname, descr|
        _feed_table descr
        opts = descr[:data_source].to_hash(name: tname)
        name = "#{@graph_name.downcase}:#{opts[:name]}"
        opts[:context] = @experiment.job_url + '/measurement_points/' + name
        opts[:data_url] = opts[:context] + '/data'
        opts
      end
      @opts[:data_sources] = dss
      @experiment.send_status(:graph, @opts)
    end

    def _feed_table(descr)
      query = descr[:query]
      table = descr[:table]
      limit = DEF_QUERY_LIMIT
      offset = 0
      t_query = LabWiki::Plugin::Experiment::Util::retry(DEF_QUERY_INTERVAL) do
        if connected?
          begin
            q = "#{query} LIMIT #{limit} OFFSET #{offset}"
            rows = @connection.fetch(q).all
            unless rows.empty?
              debug ">>> Found #{rows.size} rows - offset #{offset}"
              row_values = rows.map do |v|
                if v.is_a? Hash
                  v.values
                else
                  error "Rows not returned as hash, this should NOT happen. DB connected? #{connected?} - #{v}"
                  nil
                end
              end.compact
              table.add_rows row_values
              offset += row_values.length
            end
          rescue => e
            warn "Exception while running query '#{q}' - #{e}"
            rows = nil
          end
        end
        false # keep on going
      end
      synchronize do
        @periodic_timers[:query] = t_query
      end
    end

    def connected?
      @connection != nil
    end
  end # class
end # module
