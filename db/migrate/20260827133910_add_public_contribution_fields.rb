class AddPublicContributionFields < ActiveRecord::Migration[8.1]
  # A contribution created from the public payments page.
  #
  # Until now every contribution belonged to a household, because every one came
  # from a registrar. Anyone can now create a payment reference — including
  # someone in the diaspora who is not a Nyika household at all — so the
  # household becomes optional and the giver identifies themselves instead.
  #
  # Where the mobile number matches a registered household we still attach it,
  # so the household's own receipts page shows the payment.
  def change
    add_column :contributions, :origin, :integer, null: false, default: 0
    add_column :contributions, :contributor_name, :string
    add_column :contributions, :contributor_contact, :string
    add_column :contributions, :contributor_number, :string  # normalised, for matching
    add_column :contributions, :purpose_note, :string

    change_column_null :contributions, :household_id, true

    add_index :contributions, :origin
    add_index :contributions, :contributor_number
  end
end
