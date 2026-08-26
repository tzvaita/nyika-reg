class AddSourceChannelToVersions < ActiveRecord::Migration[8.1]
  # The brief defines the audit event as: actor, timestamp, action, old value,
  # new value, reason and SOURCE CHANNEL. The channel is what distinguishes an
  # edit made for someone by a registrar from one the household made themselves,
  # which the pilot has to report on ("how many residents can update without
  # assistance").
  def change
    add_column :versions, :source_channel, :string
    add_index  :versions, :source_channel
  end
end
