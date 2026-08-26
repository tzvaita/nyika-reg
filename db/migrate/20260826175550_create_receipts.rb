class CreateReceipts < ActiveRecord::Migration[8.1]
  # The brief's "Receipt record": receipt ID, contribution, reference, payment
  # rail, captured by, verification status.
  #
  # A receipt is EVIDENCE THAT A PAYMENT HAPPENED SOMEWHERE ELSE — on EcoCash, at
  # a bank, or in cash to an authorised collector. The registry holds the proof
  # and the reference, never the money. Cash receipts carry the most risk, which
  # is why verification is a second pair of eyes here as everywhere else.
  def change
    create_table :receipts do |t|
      t.string     :reference, null: false
      t.references :contribution, null: false, foreign_key: true

      t.integer    :payment_rail, null: false, default: 0
      # What the rail itself issued, e.g. an EcoCash transaction id. This is what
      # a payment gets matched on.
      t.string     :external_reference

      t.decimal    :amount, precision: 12, scale: 2
      t.date       :issued_on, null: false

      t.integer    :verification_status, null: false, default: 0
      t.references :captured_by, foreign_key: { to_table: :users }
      t.references :verified_by, foreign_key: { to_table: :users }
      t.datetime   :verified_at

      # Where the banking proof or photographed slip is stored. A link, never the
      # file, and never card or account credentials.
      t.string     :proof_link
      t.text       :note

      t.timestamps
    end

    add_index :receipts, :reference, unique: true
    add_index :receipts, :external_reference
    add_index :receipts, :verification_status
  end
end
