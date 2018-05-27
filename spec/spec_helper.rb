# frozen_string_literal: true

require 'bundler/setup'
require 'active_support'
require 'active_support/core_ext'
require 'elasticsearch'
require 'ostruct'
require 'securerandom'
require 'zelastic'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
