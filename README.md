# Zero-downtime indexing from ActiveRecord->Elasticsearch

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'es_index'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install es_index

## Usage
### Setup

For each ActiveRecord scope you want to index, you'll need a configuration:
```ruby
class MyModel < ApplicationRecord
  ...
end

MyModelIndex = EsIndex.new(
  client: Elasticsearch::Client.new(...),
  mapping: {
    ...
  },
  data_source: MyModel.some_scope
) do |my_model|
  # this block transforms an instance of MyModel into the hash which goes into Elasticsearch
  {
    attr_1: my_model.attr_1,
    attr_2: my_model.attr_2,
    attr_3: my_model.attr_3
  }
end
```

You can also override some defaults, if you wish:
- `index_settings`: by default there aren't any, but you can provide, for example, custom analysers
  here
- `read_alias`: by default this is the table name of the `data_source`
- `write_alias`: by default this is the `read_alias`, with `_write` appended
- `type`: by default this is `read_alias.singularize`

### Normal usage

You'll need to make sure the following gets run whenever an instance of MyModel is updated:

```ruby
indexer = EsIndex::Indexer.new(MyModelIndex)
indexer.index_record(my_model)
```

And when an instance of MyModel gets deleted:
```ruby
indexer = EsIndex::Indexer.new(MyModelIndex)
indexer.delete_by_id(my_model.id)
```

There's also some bulk-change methods which may be useful:
```ruby
indexer = EsIndex::Indexer.new(MyModelIndex)
indexer.index_batch(MyModel.where(id: [...]))
indexer.delete_by_ids([1, 2, 3])
indexer.delete_by_query(elasticsearch_query)
```

### Re-indexing

Sometimes you'll need to do a full reindex - maybe because of a bug which left the index in a bad
state, or because of a new index definition, or...anything else.

We use index aliases to make it easy to do zero-downtime reindexing. The actual indexes are
`<read_alias>_<random>`. The `read_alias` points to the single "current" index.
The `write_alias` is usually the same as the read alias, except during re-indexing, where it
points at both the old and new indices, so both receive writes. The following steps run a
full reindex:

1. `new_name = SecureRandom.hex(3)`
2. `index_manager = EsIndex::IndexManager.new(MyModelIndex)`
2. `index_manager.create_index(new_name)`
3. `index_manager.populate_index(new_name, batch_size: 3000)`
4. Check that the new index is looking alrightish
5. `index_manager.switch_read_index(new_name)`
6. Probably do some more checks, then
7. `index_manager.stop_dual_writes`
8. `index_manager.cleanup_old_indices`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/carwow/es_index.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
