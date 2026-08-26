class ConsentRecord < ApplicationRecord
  include Auditable

  # PURPOSE-SPECIFIC CONSENT. Each purpose is agreed to separately; there is no
  # blanket consent anywhere in this system. Consent to be contacted is not
  # consent to be enrolled in a programme, and neither is consent to be paid.
  enum :purpose, {
    village_admin: 0,  # hold the record for village administration
    communication: 1,  # be contacted about village matters
    programme: 2,      # be considered for government/NGO programmes
    payment: 3         # receive or be reconciled against payments
  }, validate: true

  enum :channel, {
    in_person: 0,   # spoken, with a registrar present
    paper_form: 1,  # signed or thumb-printed form
    whatsapp: 2,
    sms: 3,
    ussd: 4
  }, validate: true

  belongs_to :person
  belongs_to :recorded_by, class_name: "User", optional: true

  validates :consent_version, presence: true
  validates :granted_on, presence: true

  scope :active,    -> { where(withdrawn_at: nil) }
  scope :withdrawn, -> { where.not(withdrawn_at: nil) }
  scope :for_purpose, ->(purpose) { where(purpose: purpose) }

  def withdrawn?
    withdrawn_at.present?
  end

  # Withdrawal is recorded, never deleted — the fact that consent once existed,
  # and that it was withdrawn, is itself part of the record.
  def withdraw!(reason:, note: nil)
    return if withdrawn?

    self.change_reason = reason
    update!(withdrawn_at: Time.current, withdrawal_note: note)
  end

  def to_s
    "#{purpose.humanize} (#{consent_version})#{withdrawn? ? " — withdrawn" : ""}"
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id purpose consent_version channel granted_on withdrawn_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[person recorded_by]
  end
end
