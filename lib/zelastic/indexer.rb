# frozen_string_literal: true

module Zelastic
  class Indexer
    class IndexingError < StandardError
      attr_reader :errors

      def initialize(result)
        @errors = result['items'].map do |item|
          item['error'] || item.fetch('index', {})['error']
        end.compact
        super("Errors indexing: #{errors.join(', ')}")
      end
    end

    extend Forwardable

    def initialize(config)
      @config = config
    end

    def index_batch(batch, client: nil, index_name: nil)
      logger.info("ES: Indexing #{config.type} record")

      version = current_version
      execute_bulk(client: client, index_name: index_name) do |index_name|
        batch.map do |record|
          index_command(index: index_name, version: version, record: record)
        end
      end
    end

    def index_record(record)
      version = current_version

      execute_bulk do |index_name|
        [index_command(index: index_name, version: version, record: record)]
      end
    end

    def delete_by_id(id)
      delete_by_ids([id])
    end

    def delete_by_ids(ids)
      logger.info('ES: Deleting batch records')

      execute_bulk do |index_name|
        ids.map do |id|
          {
            delete: {
              _index: index_name,
              _type: config.type,
              _id: id
            }
          }
        end
      end
    end

    def delete_by_query(query)
      logger.info('ES: Deleting batch records')

      config.clients.map do |client|
        client.delete_by_query(index: config.write_alias, body: { query: query })
      end
    end

    private

    attr_reader :config
    def_delegators :config, :logger

    def current_version
      config.data_source.connection.select_one('SELECT txid_current()').fetch('txid_current')
    end

    def write_indices(client)
      client.indices.get_alias(name: config.write_alias).keys
    end

    def index_command(index:, version:, record:)
      {
        index: {
          _index: index,
          _type: config.type,
          _id: record.id,
          _version: version,
          _version_type: :external,
          data: config.index_data(record)
        }
      }
    end

    def execute_bulk(client: nil, index_name: nil)
      clients = Array(client || config.clients)

      clients.map do |current_client|
        indices = Array(index_name || write_indices(current_client))

        commands = indices.flat_map { |index| yield(index) }

        current_client.bulk(body: commands).tap do |result|
          raise IndexingError, result if result['errors']
        end
      end
    end
  end
end
