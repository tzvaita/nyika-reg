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

  # What Twilio calls a status, mapped onto ours.
  #
  # "sent" from a provider means accepted for delivery — it is NOT the same as
  # arriving, which is exactly why callbacks matter. Only "delivered" and "read"
  # say a message actually reached a handset.
  PROVIDER_STATUSES = {
    "queued" => :queued, "accepted" => :queued, "scheduled" => :queued,
    "sending" => :queued,
    "sent" => :sent,
    "delivered" => :delivered,
    "read" => :delivered,
    "failed" => :failed, "undelivered" => :failed
  }.freeze

  def apply_provider_status!(provider_status, error_code: nil, error_message: nil)
    mapped = PROVIDER_STATUSES[provider_status.to_s.downcase]
    return false if mapped.nil?

    attributes = { provider_status: provider_status, status: mapped }

    # Callbacks can arrive out of order, so a late "sent" must not undo a
    # "delivered" that already landed.
    return false if regression?(mapped)

    attributes[:delivered_at] = Time.current if mapped == :delivered && delivered_at.blank?
    attributes[:read_at] = Time.current if provider_status.to_s.casecmp?("read") && read_at.blank?
    attributes[:sent_at] ||= Time.current if mapped == :sent && sent_at.blank?

    if mapped == :failed
      attributes[:provider_error_code] = error_code
      attributes[:error_message] = [ error_code, error_message ].compact.join(" ").presence
    end

    update!(attributes)
    true
  end

  def read?
    read_at.present?
  end

  # Did it actually reach a handset, as opposed to being accepted by a provider?
  def reached_recipient?
    delivered_at.present?
  end

  private

  RANK = { "queued" => 0, "sent" => 1, "delivered" => 2, "failed" => 3, "skipped" => 3 }.freeze

  def regression?(mapped)
    # Failure always wins: a message that failed did not arrive, whenever we
    # hear about it.
    return false if mapped == :failed

    RANK.fetch(mapped.to_s, 0) < RANK.fetch(status.to_s, 0)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id channel to_number template_key status skip_reason disclosure
       sent_at delivered_at attempts created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[conversation household]
  end
end
