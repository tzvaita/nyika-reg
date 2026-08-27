class AddPinToHouseholds < ActiveRecord::Migration[8.1]
  # A PIN, so that holding the link is no longer enough on its own.
  #
  # The identifier already exists — contact_number is a normalised E.164 phone
  # number — so this adds only the credential.
  #
  # PINs are ISSUED BY THE OFFICE, never chosen from a phone number alone. If
  # anyone who knew a number could claim a PIN, the number would be the only real
  # credential, which is the weakness this is meant to fix.
  def up
    add_column :households, :pin_digest, :string
    add_column :households, :pin_set_at, :datetime
    # True while the PIN is the one a registrar issued: the household must
    # choose their own before anything else is reachable.
    add_column :households, :pin_temporary, :boolean, null: false, default: false
    # Six digits against a known number is brute-forceable, so failures count.
    add_column :households, :pin_failed_attempts, :integer, null: false, default: 0
    add_column :households, :pin_locked_until, :datetime
    add_column :households, :pin_issued_by_id, :bigint

    add_index :households, :pin_issued_by_id
    add_foreign_key :households, :users, column: :pin_issued_by_id
  end

  def down
    remove_foreign_key :households, column: :pin_issued_by_id
    remove_column :households, :pin_issued_by_id
    remove_column :households, :pin_locked_until
    remove_column :households, :pin_failed_attempts
    remove_column :households, :pin_temporary
    remove_column :households, :pin_set_at
    remove_column :households, :pin_digest
  end
end
