class CreateConversations < ActiveRecord::Migration[8.1]
  # One conversation per phone number: where someone is in a menu, and what they
  # have said so far in the flow they are part-way through.
  #
  # The household link is CACHED, not authoritative — it is re-resolved from the
  # number on each message, so changing a household's contact details takes
  # effect immediately rather than leaving a stale conversation attached.
  def change
    create_table :conversations do |t|
      t.string   :contact_number, null: false
      t.string   :channel, null: false, default: "whatsapp"

      t.string   :state, null: false, default: "idle"
      # In-flight answers for a multi-step flow (the name someone gave before we
      # asked where they live). Cleared when the flow ends or the session lapses.
      t.jsonb    :context, null: false, default: {}

      t.references :household, foreign_key: true

      t.datetime :last_message_at
      t.integer  :message_count, null: false, default: 0

      t.timestamps
    end

    add_index :conversations, [ :contact_number, :channel ], unique: true
  end
end
