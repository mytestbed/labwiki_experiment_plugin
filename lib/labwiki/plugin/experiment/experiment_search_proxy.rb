require 'labwiki/plugin/experiment/experiment'
require 'labwiki/rack/search_handler'
require "em-synchrony"
require "em-synchrony/em-http"

module LabWiki::Plugin::Experiment
  class ExperimentSearchProxy <  OMF::Base::LObject
    def self.instance
      unless proxy = OMF::Web::SessionStore[self.to_s, :proxy]
        proxy = OMF::Web::SessionStore[self.to_s, :proxy] = self.new
      end
      proxy
    end

    def find(pattern, opts, wopts, &cbk)
      puts "EXP WOPTS: #{wopts}"
      opts[:mime_type] = 'text/ruby'
      OMF::Web::ContentRepository.find_files(pattern, opts, &cbk)

      query(pattern, wopts, &cbk)
    end

    def query(pat, wopts, &cbk)
      unless @url
        js = wopts[:job_service]
        @url = "http://#{js[:host]}:#{js[:port] || 80}/jobs?"
      end
      username = OMF::Web::SessionStore[:id, :user]
      EventMachine.synchrony do
        begin
          resp = EventMachine::HttpRequest.new(@url).get(query: {pat: pat, username: username})
          if resp.error
            @error_at = Time.now
          # end
          # unless (rcode = resp.response_header.status) == 200
            warn "Job search failed #{resp.response} - #{resp.inspect}"
          else
            reply = JSON.parse(resp.response)
            #puts "JOB SEARCH REPLY: #{reply}"
            # TODO: Select 10 latest ones, but there is no date in reply
            reply.reverse[0 .. 10].each do |r|
              cbk.call({
                url: r["href"], name: r["name"], status: r['status'],
                mime_type: 'experiment', widget: 'experiment' #, plugin: 'experiment'
              })
            end
            #@results[pat] = {time: Time.now, jobs: reply}
            #p reply
          end

          #puts "RES: #{resp.methods.sort}"
          #puts "RES: #{resp.inspect}"
        rescue => ex
          warn "Exception while searching job service - #{ex}"
        end
      end
    end

    def initialize
      @results = {}
      @error_at = nil
    end
  end
end
