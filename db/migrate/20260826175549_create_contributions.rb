class CreateContributions < ActiveRecord::Migration[8.1]
  # The brief's "Contribution record": contribution ID, campaign, household,
  # amount or item, payment method, reference, status.
  #
  # POLITICAL FIREWALL: a contribution belongs to a campaign and a household, and
  # to NOTHING ELSE. There is deliberately no association to a programme case,
  # and none should be added. Both documents are explicit that contribution flows
  # must never be mixed with welfare, vulnerability or government programme data
  # — the risk being that giving, or not giving, starts to affect who gets
  # support. Keeping the tables unlinked is what makes that structural rather
  # than a matter of good behaviour.
  def change
    create_table :contributions do |t|
      t.string     :reference, null: false

      t.references :mobilisation_campaign, null: false, foreign_key: true
      t.references :household, null: false, foreign_key: true

      # Money, materials or labour — the deck treats all three as contributions.
      t.integer    :contribution_kind, null: false, default: 0
      t.decimal    :amount, precision: 12, scale: 2
      t.string     :item_description

      t.integer    :payment_method
      # The reference the resident gets from the rail, used to match the payment.
      t.string     :payment_reference

      # pledged -> pending -> reconciled, with exception for anything that will
      # not match. Exceptions are a queue to work, not a failure to hide.
      t.integer    :status, null: false, default: 0
      t.text       :exception_note

      t.date       :pledged_on, null: false
      t.references :recorded_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :contributions, :reference, unique: true
    add_index :contributions, :status
    add_index :contributions, [ :mobilisation_campaign_id, :household_id ]
    add_index :contributions, :payment_reference
  end
end
