module CurrencyHelper
  CurrencyDisplay = Struct.new(:name, :amount, :dom_id, :symbol, :currency_id, keyword_init: true)

  def currency_balances_for(user)
    return [] unless user

    user.ensure_currency_wallets!(Currency.all)
    wallets = user.user_currencies.includes(:currency).sort_by { |wallet| wallet.currency&.name.to_s }

    wallets.map do |wallet|
      currency = wallet.currency
      CurrencyDisplay.new(
        name: currency&.name,
        amount: wallet.balance.to_i,
        dom_id: currency_dom_id(currency),
        symbol: currency&.symbol,
        currency_id: currency&.id
      )
    end
  end

  def currency_dom_id(currency_or_name)
    slug = currency_slug(currency_or_name)
    slug = "unknown" if slug.blank?
    "user-currency-#{slug}"
  end

  private

  def currency_slug(currency_or_name)
    name =
      case currency_or_name
      when Currency
        currency_or_name.name
      when UserCurrency
        currency_or_name.currency&.name
      else
        currency_or_name.respond_to?(:name) ? currency_or_name.name : currency_or_name.to_s
      end

    name.to_s.parameterize(separator: "-")
  end
end
