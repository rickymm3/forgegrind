class DeduplicateCurrencies < ActiveRecord::Migration[7.1]
  def up
    duplicates = Currency.group(:name).having("COUNT(*) > 1").pluck(:name)
    duplicates.each do |name|
      currency_ids = Currency.where(name: name).order(:id).pluck(:id)
      next if currency_ids.size <= 1

      keep_id = currency_ids.shift
      merge_ids = currency_ids

      Currency.transaction do
        # First, merge duplicate user_currencies to avoid unique constraint collisions.
        uc_scope = UserCurrency.where(currency_id: [keep_id] + merge_ids)

        uc_scope.group(:user_id).having("COUNT(*) > 1").pluck(:user_id).each do |user_id|
          entries = uc_scope.where(user_id: user_id).order(:id)
          keeper = entries.first
          total_balance = entries.sum(:balance)

          keeper.update_columns(balance: total_balance, currency_id: keep_id)
          UserCurrency.where(id: entries.pluck(:id) - [keeper.id]).delete_all
        end

        # Repoint remaining references to the kept currency id.
        UserCurrency.where(currency_id: merge_ids).update_all(currency_id: keep_id)
        Egg.where(currency_id: merge_ids).update_all(currency_id: keep_id)

        # Remove duplicate currency records.
        Currency.where(id: merge_ids).delete_all
      end
    end

    add_index :currencies, :name, unique: true unless index_exists?(:currencies, :name, unique: true)
  end

  def down
    remove_index :currencies, :name if index_exists?(:currencies, :name, unique: true)
    # Note: duplicate rows are not restored in down migration.
  end
end
