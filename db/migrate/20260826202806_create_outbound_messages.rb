class CreateOutboundMessages < ActiveRecord::Migration[8.1]
  # The outbox: everything the registry tried to send, and what became of it.
  #
  # Also the DISCLOSURE LOG. Reading household data over WhatsApp was a
  # deliberate choice, and a phone number is weak proof of identity, so what was
  # shown, to which number and when must be answerable afterwards.
  def change
    create_table :outbound_messages do |t|
      t.string   :channel, null: false, default: "whatsapp"
      t.string   :to_number, null: false
      t.text     :body, null: false

      # Which message this is — "menu", "case.status", "reminder.evidence" — so
      # the outbox can be read and counted without parsing bodies.
      t.string   :template_key

      t.integer  :status, null: false, default: 0
      t.string   :skip_reason
      t.text     :error_message
      t.integer  :attempts, null: false, default: 0

      t.string   :provider_message_id
      t.datetime :sent_at
      t.datetime :delivered_at

      t.references :conversation, foreign_key: true
      t.references :household, foreign_key: true

      # True where the body carried registry data rather than a prompt, so
      # disclosures can be reported on separately.
      t.boolean  :disclosure, null: false, default: false

      t.timestamps
    end

    add_index :outbound_messages, :status
    add_index :outbound_messages, :to_number
    add_index :outbound_messages, :template_key
  end
end
