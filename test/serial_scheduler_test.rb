# frozen_string_literal: true
require_relative "test_helper"

SingleCov.covered!

describe SerialScheduler do
  let(:output) { StringIO.new }
  let(:logger) { Logger.new(output) }
  let(:scheduler) { SerialScheduler.new(logger: logger) }

  it "has a VERSION" do
    SerialScheduler::VERSION.must_match /^[\.\da-z]+$/
  end

  describe "#run" do
    def fake_fork
      Process.expects(:wait)
      scheduler.expects(:fork).yields.returns(123_456)
    end

    def run_scheduler(time)
      Tempfile.open do |f|
        f.sync = true
        yield f
        Thread.new do
          sleep time
          scheduler.stop
        end
        scheduler.run # blocks
        f.close
        maxitest_wait_for_extra_threads
        File.read(f.path)
      end
    end

    it "executes one job at a time" do
      run_scheduler(0.5) do |f|
        scheduler.add :foo, interval: 1, timeout: 3 do
          f.puts 1
          sleep 1
        end
        sleep 0.1
        scheduler.add :bar, interval: 1, timeout: 2 do
          f.puts 2
        end
      end.must_equal "1\n"
    end

    it "runs all jobs" do
      run_scheduler(0.5) do |f|
        scheduler.add :foo, interval: 1, timeout: 3 do
          f.puts 1
        end
        sleep 0.1
        scheduler.add :bar, interval: 1, timeout: 2 do
          f.puts 2
        end
      end.must_equal "1\n2\n"
    end

    it "executes multiple times" do
      run_scheduler(1.5) do |f|
        scheduler.add(:foo, interval: 1, timeout: 3) { f.puts 1 }
      end.must_equal "1\n1\n"
    end

    it "does not create zombies" do
      run_scheduler(1) do
        scheduler.add(:foo, interval: 1, timeout: 3) {}
      end
      running = `ps -ef | grep #{Process.pid} | grep -v grep`
      running.split("\n").size.must_equal 1, running
    end

    it "reports errors to rollbar" do
      calls = []
      fake_fork
      scheduler.instance_variable_set(:@error_handler, ->(e) { calls << e })
      run_scheduler 0.5 do
        scheduler.add(:foo, interval: 1, timeout: 3) { raise }
      end
      maxitest_wait_for_extra_threads # stop thread keeps running
      calls.size.must_equal 1
    end

    it "stops when waiting" do
      Time.stubs(:now).returns(Time.at(1004))
      t = Benchmark.realtime do
        run_scheduler(0.5) do |f|
          scheduler.add(:foo, interval: 5, timeout: 3) { f.puts 1 }
        end.must_equal "1\n"
      end
      t.must_be :<, 2
    end
  end

  describe "#add" do
    it "raises on interval that would block all others" do
      assert_raises ArgumentError do
        scheduler.add(:foo, interval: 0, timeout: 1) {}
      end
    end
  end
end
