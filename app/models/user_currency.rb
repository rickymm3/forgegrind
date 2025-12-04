class UserCurrency < ApplicationRecord
  belongs_to :user
  belongs_to :currency

  validates :balance, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency_id, uniqueness: { scope: :user_id }

  def credit!(amount)
    amount = amount.to_i
    return if amount.zero?

    with_lock do
      update!(balance: balance.to_i + amount)
    end
  end

  def debit!(amount)
    amount = amount.to_i
    return if amount.zero?

    with_lock do
      current_balance = balance.to_i
      raise ActiveRecord::Rollback, "Not enough #{currency.name}" if current_balance < amount

      update!(balance: current_balance - amount)
    end
  end
end
