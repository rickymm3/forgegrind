class SpecialAbility < ApplicationRecord
  has_many :pets, dependent: :nullify

  validates :reference, :name, presence: true
  validates :reference, uniqueness: true

  scope :ordered, -> { order(:name) }

  def encounter_tags_list
    Array(encounter_tags).map(&:to_s)
  end

  def encounter_tags_csv
    @encounter_tags_csv.presence || encounter_tags_list.join(", ")
  end

  def encounter_tags_csv=(value)
    @encounter_tags_csv = value
    tags = value.to_s.split(",").map { |tag| tag.strip.presence }.compact
    self.encounter_tags = tags
  end

  def metadata_json
    return @metadata_json if defined?(@metadata_json)

    metadata.present? ? JSON.pretty_generate(metadata) : ""
  end

  def metadata_json=(value)
    @metadata_json = value
    self.metadata = value.present? ? JSON.parse(value) : {}
  rescue JSON::ParserError
    errors.add(:metadata, "must be valid JSON")
  end
end
