# frozen_string_literal: true

module EsIndex
  class Indexer
    def initialize(config)
      @config = config
    end

    def index_batch(batch, index_name: nil)
      indices = Array(index_name || write_indices)
      logger.info("ES: Indexing #{config.type} record")

      version = current_version
      execute_bulk(
        indices.flat_map do |index|
          batch.map do |record|
            index_command(index: index, version: version, record: record)
          end
        end
      )
    end

    def index_record(record)
      version = current_version

      execute_bulk(
        write_indices.map do |index|
          index_command(index: index, version: version, record: record)
        end
      )
    end

    def delete_by_id(id)
      indices = client.indices.get_alias(name: config.write_alias).keys

      indices.each do |index|
        client.delete(
          index: index,
          type: config.type,
          id: id
        )
      end
    end

    def delete_by_ids(ids)
      logger.info('ES: Deleting batch records')

      indices = config.client.indices.get_alias(name: config.write_alias).keys

      execute_bulk(
        indices.flat_map do |index|
          ids.map do |id|
            {
              delete: {
                _index: index,
                _type: config.type,
                _id: id
              }
            }
          end
        end
      )
    end

    def delete_by_query(query)
      logger.info('ES: Deleting batch records')

      config.client.delete_by_query(index: config.write_alias, body: { query: query })
    end

    private

    attr_reader :config
    delegate :logger, to: :config

    def current_version
      config.data_source.connection.select_one('SELECT txid_current()').fetch('txid_current')
    end

    def write_indices
      config.client.indices.get_alias(name: config.write_alias).keys
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

    def execute_bulk(commands)
      result = config.client.bulk(body: commands)
      return result unless result['errors']
      result['items'].map { |item| item['error'] }.compact
    end
  end
end
