class ExplorationConfigCollectionStore
  Entry = Struct.new(:key, :data, keyword_init: true)

  def initialize(path:, root_key:)
    @path = path
    @root_key = root_key.to_s
  end

  def all_entries
    collection.map do |key, data|
      Entry.new(key: key, data: deep_dup(data))
    end
  end

  def find(key)
    data = collection[key.to_s]
    data && Entry.new(key: key.to_s, data: deep_dup(data))
  end

  def update!(key:, attributes:)
    payload = load_raw
    payload[@root_key] ||= {}
    payload[@root_key][key.to_s] = attributes
    File.write(@path, payload.to_yaml)
  end

  private

  def collection
    load_raw.fetch(@root_key, {})
  end

  def load_raw
    if File.exist?(@path)
      YAML.load_file(@path) || {}
    else
      {}
    end
  rescue Psych::SyntaxError => e
    Rails.logger.error("Failed to parse #{@path}: #{e.message}")
    {}
  end

  def deep_dup(object)
    case object
    when Hash
      object.each_with_object({}) { |(k, v), memo| memo[k] = deep_dup(v) }
    when Array
      object.map { |v| deep_dup(v) }
    else
      object.dup rescue object
    end
  end
end
