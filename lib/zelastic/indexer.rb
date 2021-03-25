# frozen_string_literal: true

module Zelastic
  class Indexer
    class IndexingError < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super("Errors indexing: #{errors.join(', ')}")
      end
    end

    extend Forwardable

    def initialize(config)
      @config = config
    end

    def index_batch(batch, client: nil, index_name: nil, refresh: false)
      version = current_version
      execute_bulk(client: client, index_name: index_name, refresh: refresh) do |index|
        batch.map do |record|
          index_command(index: index, version: version, record: record)
        end
      end
    end

    def index_record(record, refresh: false)
      version = current_version

      execute_bulk(refresh: refresh) do |index_name|
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
          delete_params = { _index: index_name, _id: id }
          delete_params[:_type] = config.type if config.type?

          { delete: delete_params }
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
      config.data_source.connection
            .select_one('SELECT txid_snapshot_xmax(txid_current_snapshot()) as xmax')
            .fetch('xmax')
    end

    def write_indices(client)
      client.indices.get_alias(name: config.write_alias).keys
    end

    def index_command(index:, version:, record:)
      version_params =
        if config.type?
          { _version: version, _version_type: :external, _type: config.type }
        else
          { version: version, version_type: :external }
        end

      {
        index: {
          _index: index,
          _id: record.id,
          data: config.index_data(record)
        }.merge(version_params)
      }
    end

    def execute_bulk(client: nil, index_name: nil, refresh: false)
      clients = Array(client || config.clients)

      clients.map do |current_client|
        indices = Array(index_name || write_indices(current_client))

        commands = indices.flat_map { |index| yield(index) }

        current_client.bulk(body: commands, refresh: refresh).tap do |result|
          check_errors!(result)
        end
      end
    end

    def check_errors!(result)
      return false unless result['errors']

      errors = result['items']
               .map { |item| item['error'] || item.fetch('index', {})['error'] }
               .compact

      ignorable_errors, important_errors = errors
                                           .partition { |error| ignorable_error?(error) }

      logger.warn("Ignoring #{ignorable_errors.count} version conflicts") if ignorable_errors.any?

      return unless important_errors.any?

      raise IndexingError, important_errors
    end

    def ignorable_error?(error)
      # rubocop:disable Layout/LineLength
      regexp =
        if config.type?
          /^\[#{config.type}\]\[\d+\]: version conflict, current version \[\d+\] is higher or equal to the one provided \[\d+\]$/
        else
          /^\[\d+\]: version conflict, current version \[\d+\] is higher or equal to the one provided \[\d+\]$/
        end
      # rubocop:enable Layout/LineLength
      error['type'] == 'version_conflict_engine_exception' &&
        error['reason'] =~ regexp
    end
  end
end
