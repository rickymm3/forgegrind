module InventoriesHelper
  RARITY_COLOR_MAP = {
    "legendary" => "orange-300",
    "epic" => "purple-300",
    "rare" => "blue-300",
    "uncommon" => "green-300",
    "common" => "slate-300"
  }.freeze

  def rarity_color_class(rarity)
    tone = RARITY_COLOR_MAP[rarity.to_s.downcase] || "slate-300"
    "#{tone}"
  end
end
