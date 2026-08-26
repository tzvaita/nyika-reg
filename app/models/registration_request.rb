class RegistrationRequest < ApplicationRecord
  include Auditable

  enum :status, {
    new_request: 0,  # arrived from the website, nobody has looked yet
    contacted: 1,    # the office has been in touch
    captured: 2,     # a household record now exists
    declined: 3      # not proceeding, with a reason
  }, validate: true

  belongs_to :handled_by, class_name: "User", optional: true
  belongs_to :household, optional: true

  validates :name, presence: true
  validate  :contactable

  scope :open_requests, -> { where(status: [ :new_request, :contacted ]) }

  # How long a request that went nowhere should be kept. A request holds personal
  # data about someone who has consented to nothing, so it does not sit here
  # indefinitely — see #stale? and the retention note in the README.
  RETENTION_DAYS = 90

  def stale?
    return false unless new_request? || declined?

    updated_at < RETENTION_DAYS.days.ago
  end

  def mark_contacted!(by:, note: nil, reason: nil)
    self.change_reason = reason || "Household contacted"
    update!(status: :contacted, handled_by: by, handled_at: Time.current,
            outcome_note: note.presence || outcome_note)
  end

  # Called once a registrar has actually captured them, linking the request to
  # the record it produced so the trail from website to register is visible.
  def mark_captured!(household:, by:, reason: nil)
    self.change_reason = reason || "Household captured from this request"
    update!(status: :captured, household: household, handled_by: by,
            handled_at: Time.current)
  end

  def decline!(by:, note:, reason: nil)
    self.change_reason = reason || "Request declined"
    update!(status: :declined, handled_by: by, handled_at: Time.current,
            outcome_note: note)
  end

  def to_s
    name
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name contact_method location_hint status handled_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[handled_by household]
  end

  private

  # Someone the office has no way of reaching is not a request, it is a dead end.
  def contactable
    return if contact_method.present? || location_hint.present?

    errors.add(:contact_method, "or a description of where to find you is needed")
  end
end
