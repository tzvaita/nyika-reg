class Contribution < ApplicationRecord
  include Auditable

  enum :contribution_kind, {
    money: 0,
    materials: 1,
    labour: 2
  }, validate: true

  # The rails from the deck's resident view. "Pay later" is a real answer: a
  # household saying "not yet" is information the village needs, and it is far
  # better recorded than left to memory.
  enum :payment_method, {
    ecocash: 0,
    innbucks: 1,
    bank: 2,
    cash_collector: 3,
    pay_later: 4
  }, validate: { allow_nil: true }

  enum :status, {
    pledged: 0,     # promised, nothing moved yet
    pending: 1,     # a payment is claimed but not yet matched
    reconciled: 2,  # matched against a verified receipt
    exception: 3    # will not match, and needs a human
  }, validate: true

  belongs_to :mobilisation_campaign
  belongs_to :household
  belongs_to :recorded_by, class_name: "User", optional: true

  has_many :receipts, dependent: :restrict_with_error

  # NOTE: there is deliberately no association to ProgrammeCase, and none should
  # be added. See the political-firewall note on the contributions migration.

  validates :reference, presence: true, uniqueness: true
  validates :pledged_on, presence: true
  validates :amount, numericality: { greater_than: 0 }, allow_nil: true
  validate  :money_has_an_amount
  validate  :in_kind_has_a_description
  validate  :campaign_is_open, on: :create

  before_validation :assign_reference, on: :create
  before_validation :set_pledged_on, on: :create

  scope :outstanding, -> { where(status: [ :pledged, :pending ]) }
  scope :needs_attention, -> { where(status: :exception) }

  def verified_receipts
    receipts.where(verification_status: :verified)
  end

  def receipted_amount
    verified_receipts.sum(:amount)
  end

  # Reconciliation is only ever driven by a VERIFIED receipt. A contribution
  # cannot be marked as received because someone says so.
  def reconcile!(reason: nil)
    if verified_receipts.none?
      raise ArgumentError, "a contribution can only be reconciled against a verified receipt"
    end

    if money? && amount.present? && receipted_amount != amount
      raise ArgumentError,
            "receipts total #{receipted_amount} but the contribution is #{amount} — " \
            "record this as an exception instead"
    end

    self.change_reason = reason || "Reconciled against a verified receipt"
    update!(status: :reconciled)
  end

  # Exceptions are a queue to work, not a failure to bury. The brief asks for a
  # finance exception report and this is what fills it.
  def flag_exception!(note:, reason: nil)
    self.change_reason = reason || "Flagged as a payment exception"
    update!(status: :exception, exception_note: note)
  end

  def mark_payment_claimed!(reference:, method: nil, reason: nil)
    self.change_reason = reason || "Payment reported by the household"
    update!(status: :pending, payment_reference: reference,
            payment_method: method || payment_method)
  end

  def describes
    return item_description.presence || contribution_kind.humanize unless money?

    "#{mobilisation_campaign.currency} #{format('%.2f', amount || 0)}"
  end

  def to_s
    "#{reference} — #{describes}"
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id reference contribution_kind amount item_description payment_method
       payment_reference status pledged_on created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[mobilisation_campaign household receipts recorded_by]
  end

  private

  def assign_reference
    return if reference.present?

    year = Date.current.year
    last = Contribution.where("reference LIKE ?", "CONT-#{year}-%").order(:reference).last
    seq  = last ? last.reference.split("-").last.to_i + 1 : 1
    self.reference = format("CONT-%d-%04d", year, seq)
  end

  def set_pledged_on
    self.pledged_on ||= Date.current
  end

  def money_has_an_amount
    return unless money?
    return if amount.present?

    errors.add(:amount, "is required for a money contribution")
  end

  def in_kind_has_a_description
    return if money?
    return if item_description.present?

    errors.add(:item_description, "is required for materials or labour")
  end

  def campaign_is_open
    return if mobilisation_campaign.blank? || mobilisation_campaign.open?

    errors.add(:mobilisation_campaign,
               "is not open for contributions (#{mobilisation_campaign.status})")
  end
end
