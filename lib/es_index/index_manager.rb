module EsIndex
  class IndexManager
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def create_index(unique_name)
      full_name = [config.read_alias, unique_name].join('_')

      client.indices.create(
        index: full_name,
        body: config.index_definition
      )

      config.client.indices.put_alias(index: full_name, name: config.write_alias)
    end

    def switch_read_index(new_name)
      new_index = [config.read_alias, new_name].join('_')

      old_index =
        if config.client.indices.exists_alias?(name: config.read_alias)
          config.client.indices.get_alias(name: config.read_alias).keys.first
        end

      remove_action =
        ({ remove: { index: old_index, alias: config.read_alias } } if old_index)

      config.client.indices.update_aliases(body: {
        actions: [
          remove_action,
          { add: { index: new_index, alias: config.read_alias } }
        ].compact
      })
    end

    def stop_dual_writes
      Rails.logger.info('Stopping dual writes - making index read and write aliases the same')
      current_index = config.client.indices.get_alias(name: config.read_alias).keys.first

      Rails.logger.info("Currently used index is #{current_index}")

      other_write_indices = config.client.indices.get_alias(name: config.write_alias).keys
        .reject { |name| name == current_index }

      if other_write_indices.none?
        Rails.logger.info("No write indexes that aren't the read index. Nothing to do!")
        return
      end
      Rails.logger.info("Stopping writes to #{other_write_indices.count} old ES indices: " \
                        "#{other_write_indices.join(', ')}")

      actions = other_write_indices.map do |index|
        { remove: { index: index, alias: config.write_alias } }
      end
      config.client.indices.update_aliases(body: { actions: actions })
    end

    def cleanup_old_indices
      Rails.logger.info('Cleaning up old indices in Elasticsearch')
      current_index = config.client.indices.get_alias(name: config.read_alias).keys.first

      Rails.logger.info("Currently used index is #{current_index}")

      indices_to_delete = config.client
        .cat
        .indices(format: :json)
        .map { |index| index['index'] }
        .select { |name| name.start_with?(config.read_alias) }
        .reject { |name| name == current_index }

      if indices_to_delete.none?
        Rails.logger.info('Nothing to do: no old indices')
        return
      end
      Rails.logger.info("Deleting #{indices_to_delete.count} old indices: #{indices_to_delete.join(', ')}")
      config.client.indices.delete(index: indices_to_delete)
    end

    def populate_index(unique_name = nil, batch_size: 3000)
      index_name = if unique_name
                     [config.read_alias, unique_name].join('_')
                   else
                     config.write_alias
                   end

      config.data_source.find_in_batches(batch_size: batch_size) do |batch|
        index_batch(batch, index_name: index_name)
      end
    end
  end
end
