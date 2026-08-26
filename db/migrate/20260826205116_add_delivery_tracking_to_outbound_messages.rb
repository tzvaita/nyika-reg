class AddDeliveryTrackingToOutboundMessages < ActiveRecord::Migration[8.1]
  # Until now a message was marked "sent" when Twilio accepted it, which only
  # means the provider took it — not that it reached anyone. The delivered status
  # existed but nothing could ever set it.
  #
  # Status callbacks close that gap. WhatsApp also reports reads, which is the
  # difference between "the reminder was delivered" and "the reminder was seen" —
  # worth knowing for a pilot judging whether reminders work.
  def change
    add_column :outbound_messages, :read_at, :datetime
    add_column :outbound_messages, :provider_status, :string
    add_column :outbound_messages, :provider_error_code, :string

    add_index :outbound_messages, :provider_message_id
  end
end
