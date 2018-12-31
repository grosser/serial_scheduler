# frozen_string_literal: true
require_relative "test_helper"

SingleCov.covered!

describe SerialScheduler do
  it "has a VERSION" do
    SerialScheduler::VERSION.must_match /^[\.\da-z]+$/
  end
end
