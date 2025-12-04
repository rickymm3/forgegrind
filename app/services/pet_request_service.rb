require "securerandom"

class PetRequestService
  REQUEST_NEEDS = %i[hunger hygiene boredom injury_level mood].freeze
  REQUEST_TRIGGER_THRESHOLD = 65
  COOLDOWN_RANGE_MINUTES = 5..30

  REQUEST_DEFINITIONS = {
    hunger: {
      interaction: "feed",
      title: "Snack time",
      prompt: "I'm hungry!",
      description: "Offer a quick treat to keep energy up.",
      icon: "🍖"
    },
    hygiene: {
      interaction: "wash",
      title: "Time for a bath",
      prompt: "I need a scrub!",
      description: "Freshen up to boost comfort and mood.",
      icon: "🧼"
    },
    boredom: {
      interaction: "play",
      title: "Play with me",
      prompt: "I want to play!",
      description: "A little playtime keeps spirits high.",
      icon: "🎾"
    },
    injury_level: {
      interaction: "treat",
      title: "First aid",
      prompt: "I need some care",
      description: "Patch up bumps and bruises.",
      icon: "💊"
    },
    mood: {
      interaction: "cuddle",
      title: "Comfort me",
      prompt: "I need comfort",
      description: "A cozy cuddle lifts morale.",
      icon: "🤗"
    }
  }.freeze

  def initialize(user_pet)
    @user_pet = user_pet
  end

  def refresh_request!
    return unless user_pet
    return if pending_request?
    return if cooling_down?

    candidate = eligible_needs.sample
    return unless candidate

    issue_request!(candidate)
  end

  def pending_request?
    request = current_request
    request.present? && request["status"] == "pending"
  end

  def cooling_down?
    ts = user_pet.care_request_cooldown_until
    ts.present? && ts.future?
  end

  def current_request
    user_pet.care_request.presence || {}
  end

  def accept!(use_items: false, care_item: nil)
    request = current_request
    raise PetCareService::CareError, "No active request" if request.blank? || request["status"] != "pending"

    interaction = request_interaction(request)
    result = nil

    UserPet.transaction do
      user_pet.lock!
      ticks = user_pet.catch_up_energy!
      user_pet.catch_up_needs!(save: false, care_ticks: ticks)

      if interaction
        service = PetCareService.new(
          user_pet: user_pet,
          user: user_pet.user,
          interaction_type: interaction,
          use_items: use_items,
          glow_boost: false,
          care_item: care_item
        )
        result = service.run!
      end

      resolve_request!("accepted")
    end

    result
  end

  def decline!
    return unless pending_request?

    resolve_request!("declined")
  end

  def complete_request!(status: "accepted")
    return unless pending_request?

    resolve_request!(status.to_s)
  end

  def request_definition_for(request)
    return nil unless request
    REQUEST_DEFINITIONS[request_need(request)&.to_sym]
  end

  def request_need(request)
    (request || {})["need"] || (request || {})[:need]
  end

  private

  attr_reader :user_pet

  def eligible_needs
    REQUEST_NEEDS.filter do |metric|
      next unless user_pet.respond_to?(metric)
      value = user_pet.send(metric).to_f
      value < REQUEST_TRIGGER_THRESHOLD
    end
  end

  def issue_request!(need)
    definition = REQUEST_DEFINITIONS[need.to_sym] || {}
    payload = {
      "id" => SecureRandom.uuid,
      "need" => need.to_s,
      "prompt" => definition[:prompt] || "Needs attention",
      "title" => definition[:title] || need.to_s.humanize,
      "icon" => definition[:icon] || "✨",
      "description" => definition[:description],
      "interaction" => definition[:interaction],
      "status" => "pending",
      "issued_at" => Time.current.iso8601
    }.compact

    user_pet.update!(care_request: payload, care_request_cooldown_until: nil)
  end

  def resolve_request!(status)
    req = current_request.dup
    cooldown_until = random_cooldown.from_now

    req["status"] = status
    req["resolved_at"] = Time.current.iso8601

    user_pet.update!(care_request: req, care_request_cooldown_until: cooldown_until)
  end

  def random_cooldown
    minutes = rand(COOLDOWN_RANGE_MINUTES)
    minutes.minutes
  end

  def request_interaction(request)
    definition = request_definition_for(request)
    (definition && definition[:interaction]).to_s.presence
  end
end
