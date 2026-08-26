class Receipt < ApplicationRecord
  include Auditable

  enum :payment_rail, {
    ecocash: 0,
    innbucks: 1,
    bank: 2,
    cash_collector: 3
  }, validate: true

  enum :verification_status, {
    recorded: 0,
    verified: 1,
    rejected: 2
  }, validate: true

  belongs_to :contribution
  belongs_to :captured_by, class_name: "User", optional: true
  belongs_to :verified_by, class_name: "User", optional: true

  validates :reference, presence: true, uniqueness: true
  validates :issued_on, presence: true
  validates :amount, numericality: { greater_than: 0 }, allow_nil: true
  validate  :cash_receipts_need_proof

  before_validation :assign_reference, on: :create
  before_validation :set_issued_on, on: :create

  delegate :mobilisation_campaign, :household, to: :contribution

  # Verification is a second pair of eyes, as everywhere else in the registry.
  # It matters most here: whoever collected cash must not be the person who
  # confirms that they collected it.
  def verify!(by:, reason: nil)
    if captured_by_id == by&.id
      raise ArgumentError, "the person who captured a receipt cannot verify it"
    end

    self.change_reason = reason || "Receipt verified"
    update!(verification_status: :verified, verified_by: by, verified_at: Time.current)
  end

  def reject!(by:, reason:)
    self.change_reason = reason
    update!(verification_status: :rejected, verified_by: by, verified_at: Time.current)
  end

  def to_s
    "#{reference} — #{payment_rail.humanize}"
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id reference payment_rail external_reference amount issued_on
       verification_status verified_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[contribution captured_by verified_by]
  end

  private

  def assign_reference
    return if reference.present?

    year = Date.current.year
    last = Receipt.where("reference LIKE ?", "RCPT-#{year}-%").order(:reference).last
    seq  = last ? last.reference.split("-").last.to_i + 1 : 1
    self.reference = format("RCPT-%d-%04d", year, seq)
  end

  def set_issued_on
    self.issued_on ||= Date.current
  end

  # A rail issues its own reference; cash does not. Cash is where money goes
  # missing, so it must carry banking proof or a photographed slip instead.
  def cash_receipts_need_proof
    return unless cash_collector?
    return if proof_link.present? || note.present?

    errors.add(:proof_link,
               "is required for a cash receipt — record the banking proof or slip")
  end
end
