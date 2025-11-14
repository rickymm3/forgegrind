class Admin::ContentController < Admin::BaseController
  def index
    @sections = [
      {
        title: "Eggs",
        description: "Manage adoptable eggs, costs, and art.",
        path: admin_eggs_path,
        new_path: new_admin_egg_path
      },
      {
        title: "Pets",
        description: "Tweak species stats, abilities, and evolutions.",
        path: admin_pets_path,
        new_path: new_admin_pet_path
      },
      {
        title: "Abilities",
        description: "Create combat abilities and grant permissions.",
        path: admin_abilities_path,
        new_path: new_admin_ability_path
      },
      {
        title: "Special Abilities",
        description: "Unique exploration traits per pet.",
        path: admin_special_abilities_path,
        new_path: new_admin_special_ability_path
      },
      {
        title: "Evolution Rules",
        description: "Configure branching evolution requirements.",
        path: admin_evolution_rules_path,
        new_path: new_admin_evolution_rule_path
      },
      {
        title: "Exploration Mods",
        description: "Browse and adjust base/prefix/suffix zone modifiers.",
        path: admin_mods_path
      },
      {
        title: "Pet Badges",
        description: "Create badge requirements tied to care trackers.",
        path: admin_badges_path,
        new_path: new_admin_badge_path
      },
      {
        title: "Exploration Zones",
        description: "Edit world durations, rewards, traits, and rotations.",
        path: admin_worlds_path,
        new_path: new_admin_world_path
      },
      {
        title: "User Pets",
        description: "Adjust live companions owned by players.",
        path: admin_user_pets_path
      }
    ]
  end
end
