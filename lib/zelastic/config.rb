# frozen_string_literal: true

module Zelastic
  class Config
    attr_reader :clients, :data_source

    def initialize(
      client:,
      data_source:,
      mapping:,
      **overrides,
      &index_data
    )
      @clients = Array(client)
      @data_source = data_source
      @mapping = mapping
      @index_data = index_data
      @_type = overrides.fetch(:type, true)
      @overrides = overrides
    end

    def type?
      @_type
    end

    def index_data(model)
      @index_data.call(model)
    end

    def read_alias
      @read_alias ||= overrides.fetch(:read_alias) { data_source.table_name }
    end

    def write_alias
      @write_alias ||= overrides.fetch(:write_alias) { [read_alias, 'write'].join('_') }
    end

    def type
      @type ||= overrides.fetch(:type, read_alias.singularize)
    end

    def logger
      return Rails.logger if defined?(Rails)

      @logger ||= Logger.new($stdout)
    end

    def index_definition
      {
        settings: overrides.fetch(:index_settings, {}),
        mappings: type ? { type => mapping } : mapping
      }
    end

    private

    attr_reader :overrides, :mapping
  end
end
