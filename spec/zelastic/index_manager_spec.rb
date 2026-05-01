# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Zelastic::IndexManager do
  let(:config) do
    Zelastic::Config.new(
      client: client,
      data_source: data_source,
      mapping: mapping,
      logger: Logger.new('log/test.log')
    ) { |_| {} }
  end

  let(:client) do
    Elasticsearch::Client.new(
      url: ENV.fetch('ELASTICSEARCH_URL', 'http://localhost:9200')
    )
  end
  let(:data_source) do
    lambda do
      class_double(
        ActiveRecord::Base,
        table_name: 'reindex_test',
        connection: double(:connection, select_one: { 'xmax' => 1000 })
      )
    end
  end
  let(:mapping) { { properties: {} } }
  let(:index_id) { SecureRandom.hex(3) }

  subject(:index_manager) { described_class.new(config) }

  before do
    index_manager.create_index(index_id)
    index_manager.switch_read_index(index_id)
    index_manager.stop_dual_writes
    index_manager.cleanup_old_indices
  end

  def flush!
    client.indices.flush(index: config.read_alias)
    client.indices.refresh(index: config.read_alias)
  end

  def index_documents(docs)
    indexer = Zelastic::Indexer.new(config)
    indexer.index_batch(docs.map { |doc| OpenStruct.new(id: doc[:id]) })
    flush!
  end

  describe '#current_read_index' do
    it 'returns the current read index name' do
      expected_index = "#{config.read_alias}_#{index_id}"
      expect(index_manager.current_read_index).to eq(expected_index)
    end
  end

  describe '#current_write_index' do
    it 'returns the current write index name' do
      expected_index = "#{config.read_alias}_#{index_id}"
      expect(index_manager.current_write_index).to eq(expected_index)
    end
  end

  describe '#reindex_from_local' do
    let(:source_index_id) { SecureRandom.hex(3) }
    let(:dest_index_id) { SecureRandom.hex(3) }

    before do
      # Create a source index with some documents
      index_manager.create_index(source_index_id)
      index_manager.switch_read_index(source_index_id)
      index_manager.stop_dual_writes
      index_manager.cleanup_old_indices

      index_documents([{ id: 1 }, { id: 2 }, { id: 3 }])

      # Create a destination index
      index_manager.create_index(dest_index_id)
    end

    it 'copies documents from source to destination index' do
      source_index = "#{config.read_alias}_#{source_index_id}"
      dest_index = "#{config.read_alias}_#{dest_index_id}"

      index_manager.reindex_from_local(source_index: source_index, dest_index: dest_index, wait_for_completion: true)

      client.indices.refresh(index: dest_index)
      result = client.count(index: dest_index)

      expect(result['count']).to eq(3)
    end

    it 'requires explicit dest_index parameter' do
      source_index = "#{config.read_alias}_#{source_index_id}"
      dest_index = "#{config.read_alias}_#{dest_index_id}"

      index_manager.reindex_from_local(source_index: source_index, dest_index: dest_index, wait_for_completion: true)

      client.indices.refresh(index: dest_index)
      result = client.count(index: dest_index)

      expect(result['count']).to eq(3)
    end

    context 'with op_type: "create" and conflicts: "proceed"' do
      it 'does not overwrite existing destination documents and does not abort on conflicts' do
        source_index = "#{config.read_alias}_#{source_index_id}"
        dest_index = "#{config.read_alias}_#{dest_index_id}"

        client.index(index: dest_index, id: 1, body: { marker: 'pre-existing' }, refresh: true)

        response = index_manager.reindex_from_local(
          source_index: source_index,
          dest_index: dest_index,
          wait_for_completion: true,
          op_type: 'create',
          conflicts: 'proceed'
        )

        expect(response['version_conflicts']).to be >= 1

        client.indices.refresh(index: dest_index)
        existing = client.get(index: dest_index, id: 1)
        expect(existing['_source']).to eq('marker' => 'pre-existing')

        expect(client.count(index: dest_index)['count']).to eq(3)
      end
    end
  end
end
