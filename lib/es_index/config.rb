# frozen_string_literal: true

module EsIndex
  class Config
    attr_reader :client, :data_source

    def initialize(
      client:,
      data_source:,
      mapping:,
      **overrides,
      &index_data
    )
      @client = client
      @data_source = data_source
      @mapping = mapping
      @index_data = index_data
      @overrides = overrides
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
      @logger ||= Logger.new(STDOUT)
    end

    def index_definition
      {
        settings: overrides.fetch(:index_settings, {}),
        mappings: { type => mapping }
      }
    end

    private

    attr_reader :overrides, :mapping
  end
end
