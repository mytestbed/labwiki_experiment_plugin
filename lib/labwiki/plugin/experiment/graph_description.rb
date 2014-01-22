
require 'uri'

module LabWiki::Plugin::Experiment

  # Hold the description for a graph defined for an experiment
  #
  class GraphDescription < OMF::Base::LObject

    attr_reader :name, :type, :mstreams

    def parse(type, descr)
      type = type.split(':')
      descr = URI.decode(descr)

      debug "parse: #{type}--#{descr}"
      case type[0]
      when 'START'
        @name = descr
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
      when 'STOP'
        # ignore
      else
        warn("Unknown graph description type '#{type.inspect}'")
      end
    end

    # return a hash describing the graph suitable for the browser side
    # renderer
    #
    def render_option()
      @opts
    end

    def initialize
      @mstreams = {}
      @opts = {
        :margin => {:left => 80, :right => 50}
      }
    end

    def to_json
      { name: @name, type: @type, opts: @opts, mstreams: @mstreams }.to_json
    end

    def from_json(json)
      hash = JSON.parse(json)
      @name = hash[:name]
      @type = hash[:type]
      @opts = hash[:opts]
      @mstreams = hash[:mstreams]
    end
  end # class
end # module