# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Zelastic::Indexer do
  let(:type) { Gem::Version.new(client.info.dig('version', 'number')) <= Gem::Version.new('7.0.0') }
  let(:config) do
    Zelastic::Config.new(
      client: client,
      data_source: data_source,
      mapping: mapping,
      type: type
    ) { |_| {} }
  end

  let(:client) do
    Elasticsearch::Client.new(url: ENV.fetch('ELASTICSEARCH_URL', 'http://localhost:9200'))
  end
  let(:mapping) { { properties: {} } }
  let(:data_source) do
    db_conn = double(:db_conn, select_one: { 'xmax' => @xmax })
    double(:data_source, table_name: 'table_name', connection: db_conn)
  end
  let(:index_id) { SecureRandom.hex(3) }

  before do
    @xmax = 6666
    index_manager = Zelastic::IndexManager.new(config)
    index_manager.create_index(index_id)
    index_manager.switch_read_index(index_id)
    index_manager.stop_dual_writes
    index_manager.cleanup_old_indices
  end

  def flush!
    client.indices.flush(index: config.read_alias)
    client.indices.refresh(index: config.read_alias)
  end

  def get_all
    client.search(
      index: config.read_alias,
      size: 100,
      body: { version: true, query: { match_all: {} } }
    )
  end

  subject(:indexer) { described_class.new(config) }

  describe '#index_batch' do
    it 'pushes records to the index' do
      indexer.index_batch([OpenStruct.new(id: 1), OpenStruct.new(id: 2)])
      flush!
      results = get_all
      expect(results['hits']['hits'].map { |hit| hit['_id'].to_i }).to contain_exactly(1, 2)
    end

    it 'silently ignores version conflicts, when the new version is lower' do
      indexer.index_batch([OpenStruct.new(id: 1), OpenStruct.new(id: 2)])
      @xmax = 1000
      indexer.index_batch([OpenStruct.new(id: 1), OpenStruct.new(id: 2)])
      flush!

      results = get_all
      expect(results['hits']['hits'].map { |hit| hit['_id'].to_i }).to contain_exactly(1, 2)
      expect(results['hits']['hits'].map { |hit| hit['_version'].to_i })
        .to contain_exactly(6666, 6666)
    end
  end

  describe '#index_record' do
    it 'pushes a record to the index' do
      indexer.index_record(OpenStruct.new(id: 1))
      flush!
      results = get_all
      expect(results['hits']['hits'].map { |hit| hit['_id'].to_i }).to contain_exactly(1)
    end

    it 'silently ignores version conflicts, when the new version is lower' do
      indexer.index_record(OpenStruct.new(id: 1))
      @xmax = 1000
      indexer.index_record(OpenStruct.new(id: 1))
      flush!

      results = get_all
      expect(results['hits']['hits'].map { |hit| hit['_id'].to_i }).to contain_exactly(1)
      expect(results['hits']['hits'].map { |hit| hit['_version'].to_i }).to contain_exactly(6666)
    end
  end

  describe '#delete_by_id' do
    it 'deletes that ID' do
      indexer.index_batch([OpenStruct.new(id: 1), OpenStruct.new(id: 2)])
      flush!
      indexer.delete_by_id(1)
      flush!
      results = get_all
      expect(results['hits']['hits'].map { |hit| hit['_id'].to_i }).to contain_exactly(2)
    end
  end

  describe '#delete_by_ids' do
    it 'deletes the specified IDs' do
      indexer.index_batch([OpenStruct.new(id: 1), OpenStruct.new(id: 2), OpenStruct.new(id: 3)])
      flush!
      indexer.delete_by_ids([1, 3])
      flush!
      results = get_all
      expect(results['hits']['hits'].map { |hit| hit['_id'].to_i }).to contain_exactly(2)
    end
  end
end
