# frozen_string_literal: true

require 'timeout'
require 'json'
require 'logger'

class SerialScheduler
  class Producer
    attr_reader :name, :next, :timeout, :block

    def initialize(name, interval: nil, timeout:, cron: nil, &block)
      if cron
        cron = Fugit.do_parse_cron(cron)
      elsif !interval || interval < 1 || !interval.is_a?(Integer)
        raise ArgumentError
      end

      @name = name
      @interval = interval
      @cron = cron
      @timeout = timeout
      @block = block
      @next = nil
    end

    def start(now)
      @next =
        if @cron
          @cron.next_time(Time.at(now)).to_i
        else
          # interval 1s: do not wait
          # interval 1d: if we are 1 hour into the day next execution is in 23 hours
          now + (@interval - (now % @interval) - 1)
        end
    end

    def next!
      if @cron
        @next = @cron.next_time(Time.at(@next)).to_i
      else
        @next += @interval
      end
    end
  end

  def initialize(logger: Logger.new(STDOUT), error_handler: ->(e) { raise e })
    @logger = logger
    @error_handler = error_handler

    @producers = []
    @stopped = false
  end

  # start a new thread that enqueues an execution at given interval
  def add(*args, &block)
    @producers << Producer.new(*args, &block)
  end

  def run
    now = Time.now.to_i
    @producers.each { |p| p.start now }

    loop do
      now = Time.now.to_i
      earliest = @producers.min_by(&:next)
      wait = [earliest.next - now, 0].max # do not wait when overdue

      if wait > 0
        @logger.info message: "Waiting to start job", job: earliest.name, in: wait, at: Time.at(now).to_s
        wait.times do
          break if @stopped

          sleep 1
        end
      end
      break if @stopped

      earliest.next!
      execute_in_fork earliest
    end
  end

  def stop
    @stopped = true
  end

  private

  def execute_in_fork(producer)
    @logger.info message: "Executing job", job: producer.name
    pid = fork do
      begin
        Timeout.timeout producer.timeout, &producer.block
      rescue StandardError => e # do not rescue `Exception` so it can be `Interrupt`-ed
        @logger.error message: "Error in job", job: producer.name, error: e.message
        @error_handler.call(e)
      end
    end
    Process.wait pid
  end
end
