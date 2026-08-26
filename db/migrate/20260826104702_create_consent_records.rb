class CreateConsentRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :consent_records do |t|
      t.references :person, null: false, foreign_key: true

      # PURPOSE-SPECIFIC CONSENT: one row per purpose. There is deliberately no
      # single "consented" flag anywhere in this schema — consent to be contacted
      # is not consent to be enrolled in a programme or to receive a payment.
      t.integer  :purpose, null: false

      # Which wording the person actually agreed to, and how it was given.
      t.string   :consent_version, null: false
      t.integer  :channel, null: false, default: 0
      t.date     :granted_on, null: false

      # Withdrawal is recorded, never deleted.
      t.datetime :withdrawn_at
      t.text     :withdrawal_note

      t.references :recorded_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :consent_records, [ :person_id, :purpose ]
  end
end
