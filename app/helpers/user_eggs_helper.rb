module UserEggsHelper
  STATUS_BADGE_CLASSES = {
    ready:       "border border-emerald-400/60 bg-emerald-600/25 text-emerald-200",
    in_progress: "border border-amber-400/60 bg-amber-500/20 text-amber-200",
    idle:        "border border-slate-700/60 bg-slate-900/60 text-slate-200",
    hatched:     "border border-slate-700/60 bg-slate-900/60 text-slate-200"
  }.freeze

  def egg_card_dom_id(user_egg)
    ActionView::RecordIdentifier.dom_id(user_egg, :card)
  end

  def egg_action_panel_dom_id(user_egg)
    ActionView::RecordIdentifier.dom_id(user_egg, :action_panel)
  end

  def egg_info_dom_id(user_egg)
    ActionView::RecordIdentifier.dom_id(user_egg, :info_panel)
  end

  def egg_status_badge_classes(user_egg)
    STATUS_BADGE_CLASSES.fetch(user_egg.status) { STATUS_BADGE_CLASSES[:idle] }
  end

  def egg_status_icon(user_egg)
    case user_egg.status
    when :ready
      "✨"
    when :in_progress
      "⏳"
    when :idle
      "🌱"
    else
      "🥚"
    end
  end
end
