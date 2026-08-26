class CreateInboundMessages < ActiveRecord::Migration[8.1]
  # Every message received, stored verbatim.
  #
  # Two jobs: the delivery log the brief asks for, and the EVIDENCE behind any
  # consent given in a chat. If someone agreed to be considered for a programme
  # by replying YES, the message that says so has to still exist.
  def change
    create_table :inbound_messages do |t|
      t.string   :channel, null: false, default: "whatsapp"
      t.string   :provider_message_id
      t.string   :from_number, null: false
      t.text     :body
      t.datetime :received_at, null: false

      t.references :conversation, foreign_key: true
      t.references :household, foreign_key: true

      # What the router decided to do with it, for debugging a conversation that
      # went wrong without replaying it.
      t.string   :handled_as
      t.text     :handling_note

      t.jsonb    :payload, null: false, default: {}

      t.timestamps
    end

    add_index :inbound_messages, :from_number
    # Providers retry: the same message must not be processed twice.
    add_index :inbound_messages, :provider_message_id, unique: true
  end
end
