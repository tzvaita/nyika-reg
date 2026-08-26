class AddTokenToHouseholds < ActiveRecord::Migration[8.1]
  # A per-household secret that lets a resident open their own record without an
  # account. This is what a WhatsApp or SMS message will carry once that channel
  # exists; until then a registrar copies the link by hand.
  #
  # It is a bearer credential: whoever holds the link can edit that household.
  # Household#regenerate_token! revokes one that has leaked.
  def up
    add_column :households, :token, :string
    add_index  :households, :token, unique: true

    # Backfill before making it mandatory.
    Household.reset_column_information
    Household.where(token: nil).find_each do |household|
      household.update_columns(token: Household.generate_unique_secure_token)
    end

    change_column_null :households, :token, false
  end

  def down
    remove_index  :households, :token
    remove_column :households, :token
  end
end
