class InboundMessage < ApplicationRecord
  belongs_to :conversation, optional: true
  belongs_to :household, optional: true

  validates :from_number, presence: true
  validates :received_at, presence: true

  scope :recent, -> { order(received_at: :desc) }

  before_validation :set_received_at, on: :create

  # A provider retrying a webhook must not re-run the conversation. Returns the
  # existing message when we have seen this id before.
  def self.already_seen?(provider_message_id)
    provider_message_id.present? && exists?(provider_message_id: provider_message_id)
  end

  def normalised_from
    PhoneNumber.normalise(from_number) || from_number
  end

  def text
    body.to_s.strip
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id channel from_number body received_at handled_as created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[conversation household]
  end

  private

  def set_received_at
    self.received_at ||= Time.current
  end
end
