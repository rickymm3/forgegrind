namespace :care_items do
  desc "Ensure Items exist for all entries in config/care_items.yml"
  task sync: :environment do
    config_path = Rails.root.join("config", "care_items.yml")
    unless File.exist?(config_path)
      puts "config/care_items.yml not found; nothing to sync."
      next
    end

    config = YAML.load_file(config_path) || {}
    entries = config.values.map do |group|
      group.to_h.values
    end.flatten

    created = 0
    entries.each do |entry|
      item_type = entry.with_indifferent_access[:item_type].to_s
      next if item_type.blank?

      item = Item.find_or_initialize_by(item_type: item_type)
      if item.new_record?
        item.name = entry.with_indifferent_access[:name].presence || item_type.humanize
        item.description ||= "Auto-created from care_items.yml"
        item.save!
        created += 1
        puts "Created Item #{item.name} (#{item_type})"
      end
    end

    puts created.positive? ? "Sync complete: #{created} item(s) created." : "Sync complete: no new items needed."
  end
end
