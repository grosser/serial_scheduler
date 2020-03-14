# frozen_string_literal: true
require_relative "test_helper"
require "fugit"

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
      run_scheduler(1.9) do |f|
        scheduler.add(:foo, interval: 1, timeout: 3) { f.puts 1 }
      end.must_equal "1\n1\n"
    end

    it "can run a cron" do
      run_scheduler(0.5) do |f| # 0.5 = enough time for a fork
        scheduler.expects(:sleep).at_least(1)
        scheduler.add(:foo, cron: "* * * * *", timeout: 3) { f.puts 1 }
      end.must_include "1\n"
    end

    it "does not create zombies" do
      run_scheduler(1) do
        scheduler.add(:foo, interval: 1, timeout: 3) {}
      end
      running = `ps -ef | grep #{Process.pid} | grep -v grep`
      running.split("\n").size.must_equal 1, running
    end

    it "reports errors to via handler" do
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

    it "raises on invalid cron" do
      assert_raises ArgumentError do
        scheduler.add(:foo, cron: "foo", timeout: 1) {}
      end
    end
  end

  describe SerialScheduler::Producer do
    it "advances cron" do
      now = Time.now.to_i
      now += 1 if now % 60 == 0
      p = SerialScheduler::Producer.new(:foo, cron: "* * * * *", timeout: 1)
      p.start(now)
      a = p.next
      b = p.next!
      (a - now).must_be :<, 60
      (b - a).must_equal 60
    end
  end
end
