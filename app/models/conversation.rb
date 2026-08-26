class Conversation < ApplicationRecord
  # Where someone is in a menu. Kept deliberately small: a conversation is a
  # cursor, not a record of anything about a household.
  STATES = %w[
    idle
    registering_name registering_location
    support_choosing_programme support_choosing_member support_confirming_consent
    updating_contact
    paying_choosing_campaign paying_amount
  ].freeze

  # A part-finished flow should not resume hours later with stale answers, and a
  # session that can read household data should not stay open indefinitely on a
  # handset someone else may pick up.
  SESSION_TIMEOUT = 20.minutes

  belongs_to :household, optional: true

  has_many :inbound_messages, dependent: :nullify
  has_many :outbound_messages, dependent: :nullify

  validates :contact_number, presence: true
  validates :state, inclusion: { in: STATES }

  scope :active, -> { where(last_message_at: SESSION_TIMEOUT.ago..) }

  def self.for_number(raw, channel: "whatsapp")
    number = PhoneNumber.normalise(raw) || raw.to_s
    find_or_create_by!(contact_number: number, channel: channel)
  end

  def expired?
    last_message_at.blank? || last_message_at < SESSION_TIMEOUT.ago
  end

  def in_flow?
    state != "idle"
  end

  # Re-resolved from the number on every message rather than trusted from the
  # record, so a household whose contact details changed is picked up at once.
  def resolve_household!
    self.household = Household.find_by_contact_number(contact_number) ||
                     Person.find_by_contact_number(contact_number)&.household
    self
  end

  def known?
    household.present?
  end

  def advance!(state, context_updates = {})
    update!(state: state, context: context.merge(context_updates.stringify_keys))
  end

  # Back to the top, keeping who they are but forgetting what they were doing.
  def reset!
    update!(state: "idle", context: {})
  end

  def touch_message!
    update!(last_message_at: Time.current, message_count: message_count + 1)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id contact_number channel state last_message_at message_count created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[household inbound_messages outbound_messages]
  end
end
