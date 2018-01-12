class Config
  attr_reader :data_source, :read_alias, :write_alias, :index_definition, :client

  def initialize(data_source:, read_alias: nil, write_alias: nil, index_definition:, client:, &index_data)
    @data_source = data_source
    @read_alias = read_alias || data_source.table_name
    @write_alias = write_alias || [@read_alias, 'write'].join('_')
    @type = type || @read_alias.singularize
    @index_definition = index_definition
    @client = client
    @index_data = index_data
  end

  def index_data(model)
    @index_data.call(model)
  end
end
