class WeightedPicker
  Entry = Struct.new(:value, :weight, keyword_init: true)

  def self.pick(entries, rng: Random)
    normalized = normalize(entries)
    return normalized.first&.value if normalized.size <= 1

    total = normalized.sum(&:weight)
    threshold = rng.rand(0...total)
    running = 0

    normalized.each do |entry|
      running += entry.weight
      return entry.value if threshold < running
    end

    normalized.last&.value
  end

  def self.normalize(entries)
    entries.map do |entry|
      case entry
      when Entry
        entry
      when Hash
        Entry.new(value: entry[:value] || entry[:chest_type], weight: entry[:weight].to_i)
      else
        raise ArgumentError, "Unsupported entry type: #{entry.inspect}"
      end
    end.select { |entry| entry.weight.positive? }
  end
  private_class_method :normalize
end
