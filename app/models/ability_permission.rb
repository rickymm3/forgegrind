class AbilityPermission < ApplicationRecord
  belongs_to :ability
  belongs_to :permitted, polymorphic: true
  # later you can add e.g. min_level, unlock_cost, etc. as columns here
end
