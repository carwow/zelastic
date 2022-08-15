# frozen_string_literal: true

module Zelastic
  class Config
    attr_reader :clients

    def initialize(
      client:,
      data_source:,
      mapping:,
      logger: nil,
      **overrides,
      &index_data
    )
      @clients = Array(client)
      @data_source = data_source
      @mapping = mapping
      @logger = logger
      @overrides = overrides
      @index_data = index_data
    end

    def index_data(model)
      @index_data.call(model)
    end

    def data_source
      if @data_source.respond_to? :call
        @data_source.call
      else
        @data_source
      end
    end

    def read_alias
      @read_alias ||= overrides.fetch(:read_alias) { data_source.table_name }
    end

    def write_alias
      @write_alias ||= overrides.fetch(:write_alias) { [read_alias, 'write'].join('_') }
    end

    def logger
      return Rails.logger if defined?(Rails)

      @logger ||= Logger.new($stdout)
    end

    def index_definition
      {
        settings: overrides.fetch(:index_settings, {}),
        mappings: mapping
      }
    end

    private

    attr_reader :overrides, :mapping
  end
end
