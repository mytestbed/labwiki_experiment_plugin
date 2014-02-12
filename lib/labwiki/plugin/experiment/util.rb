
# Various utility functions

module LabWiki::Plugin::Experiment
  module Util
    DEF_RETRY_INTERVAL = 5

    def self.retry(interval = DEF_RETRY_INTERVAL, &block)
      RetryHandler.new(interval, &block)
    end

    # Retries a block until it succeeds or is being
    # canceled. 'Block' is passed this object so it can call
    # 'done' if it doesn't want to called any longer.
    #
    class RetryHandler < OMF::Base::LObject
      def initialize(interval = DEF_RETRY_INTERVAL, &block)
        @block = block
        @timer = nil
        @active = true
        EM.next_tick do
          _call
          if @active # ok, first time around didn't solve it
            @timer = EM.add_periodic_timer(interval) do
              _call()
            end
          end
        end
      end

      def cancel
        debug "canceled - #{@block}"
        @timer.cancel if @timer
        @timer = nil
        @active = false
      end

      def done
        cancel
      end

      def _call
        Fiber.new do
          begin
            (@block.arity == 0) ? @block.call() : @block.call(self)
          rescue => ex
            warn "Retry '#{@block}' failed - #{ex}"
          end
        end.resume
      end
    end
  end
end # module
