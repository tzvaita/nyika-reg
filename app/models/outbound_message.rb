class OutboundMessage < ApplicationRecord
  enum :status, {
    queued: 0,
    sent: 1,
    delivered: 2,
    failed: 3,
    skipped: 4   # deliberately not sent — no consent, no number
  }, validate: true

  belongs_to :conversation, optional: true
  belongs_to :household, optional: true

  validates :to_number, presence: true
  validates :body, presence: true

  scope :disclosures, -> { where(disclosure: true) }
  scope :undelivered, -> { where(status: [ :queued, :failed ]) }

  def mark_sent!(provider_message_id: nil)
    update!(status: :sent, provider_message_id: provider_message_id,
            sent_at: Time.current, attempts: attempts + 1)
  end

  def mark_failed!(error)
    update!(status: :failed, error_message: error.to_s.truncate(500),
            attempts: attempts + 1)
  end

  # Recorded rather than silently dropped: "who we could not reach, and why" is
  # something the village office needs to see.
  def mark_skipped!(reason)
    update!(status: :skipped, skip_reason: reason)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id channel to_number template_key status skip_reason disclosure
       sent_at delivered_at attempts created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[conversation household]
  end
end
