# frozen_string_literal: true
require "bundler/setup"

require "single_cov"
SingleCov.setup :minitest

require "maxitest/autorun"
require "maxitest/timeout"
require "maxitest/threads"
require "mocha/minitest"
require "benchmark"

require "serial_scheduler/version"
require "serial_scheduler"
