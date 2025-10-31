module CurrencyHelper
  CurrencyDisplay = Struct.new(:name, :amount, keyword_init: true)

  def currency_balances_for(user)
    return [] unless user&.user_stat

    stat = user.user_stat
    [
      CurrencyDisplay.new(name: "Trophies", amount: stat.trophies),
      CurrencyDisplay.new(name: "Diamonds", amount: stat.diamonds),
      CurrencyDisplay.new(name: "Glow Essence", amount: stat.glow_essence)
    ]
  end
end
