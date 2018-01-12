module EsIndex
  class Indexer
    def initialize(config)
      @config = config
    end

    def index_batch(batch, index_name: nil)
      index_name ||= config.write_alias
      logger.info("ES: Indexing #{config.type} record")

      version = current_version
      commands = batch.map do |record|
        {
          index: {
            _index: index_name,
            _type: config.type,
            _id: record.id,
            _version: version,
            _version_type: :external,
            data: config.index_data(record)
          }
        }
      end

      result = config.client.bulk(body: commands)
      return result unless result['errors']
      result['items'].map { |item| item['error'] }.compact
    end

    def index_record(record)
      version = current_version
      indices = config.client.indices.get_alias(name: config.write_alias).keys

      commands = indices.map do |index|
        {
          index: {
            _index: index,
            _type: config.type,
            _version: version,
            _version_type: :external,
            _id: record.id,
            data: config.index_data(record)
          }
        }
      end

      result = config.client.bulk(body: commands)
      return [] unless result['errors']
      result['items'].map { |item| item['error'] }.compact
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
      commands = []

      indices.each do |index|
        commands += ids.map do |id|
          {
            delete: {
              _index: index,
              _type: config.type,
              _id: id
            }
          }
        end
      end

      result = config.client.bulk(body: commands)

      return [] unless result['errors']
      result['items'].map { |item| item['error'] }.compact
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
  end
end
