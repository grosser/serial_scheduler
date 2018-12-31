# frozen_string_literal: true

require 'timeout'
require 'json'
require 'logger'

class SerialScheduler
  def initialize(logger: Logger.new(STDOUT), error_handler: ->(e) { raise e })
    @logger = logger
    @error_handler = error_handler

    @producers = []
    @stopped = false
  end

  # start a new thread that enqueues an execution at given interval
  def add(name, interval:, timeout:, &block)
    raise ArgumentError if interval < 1 || !interval.is_a?(Integer)

    @producers << { name: name, interval: interval, timeout: timeout, block: block, next: 0 }
  end

  def run
    # interval 1s: do not wait
    # interval 1d: if we are 1 hour into the day next execution is in 23 hours
    now = Time.now.to_i
    @producers.each { |p| p[:next] = now + (p[:interval] - (now % p[:interval]) - 1) }

    loop do
      earliest = @producers.min_by { |p| p[:next] }
      wait = [earliest[:next] - Time.now.to_i, 0].max

      if wait > 0
        @logger.info message: "Waiting to start job", job: earliest[:name], time: wait
        wait.times do
          break if @stopped

          sleep 1
        end
      end
      break if @stopped

      earliest[:next] += earliest[:interval]
      execute_in_fork earliest
    end
  end

  def stop
    @stopped = true
  end

  private

  def execute_in_fork(producer)
    @logger.info message: "Executing job", job: producer[:name]
    pid = fork do
      begin
        Timeout.timeout producer[:timeout], &producer[:block]
      rescue StandardError => e # do not rescue `Exception` so it can be `Interrupt`-ed
        @logger.error message: "Error in job", job: producer[:name], error: e.message
        @error_handler.call(e)
      end
    end
    Process.wait pid
  end
end
