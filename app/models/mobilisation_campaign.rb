class MobilisationCampaign < ApplicationRecord
  include Auditable

  # No political category exists here, and none should be added. Both source
  # documents exclude political fundraising from the POC until legal and
  # governance approvals are explicit, so the option is absent rather than
  # present-and-discouraged.
  enum :campaign_type, {
    building_fund: 0,
    emergency_relief: 1,
    materials_drive: 2,
    labour_drive: 3,
    other_community: 4
  }, validate: true

  enum :status, {
    draft: 0,   # being set up; takes no contributions
    open: 1,
    closed: 2
  }, validate: true

  # Being asked and being required are different things, and a resident is
  # entitled to know which one this is.
  enum :obligation, {
    voluntary: 0,
    approved_obligation: 1
  }, validate: true

  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :reporting_owner, class_name: "User", optional: true

  has_many :contributions, dependent: :restrict_with_error
  has_many :receipts, through: :contributions

  validates :name, presence: true
  validates :reference, presence: true, uniqueness: true
  validates :opens_on, presence: true
  validates :target_amount, numericality: { greater_than: 0 }, allow_nil: true
  validate  :closes_after_it_opens

  before_validation :assign_reference, on: :create
  before_validation :set_opens_on, on: :create

  scope :live, -> { where(status: :open) }

  # A campaign cannot take contributions until someone has approved where the
  # money is to go. This is the mitigation for the brief's "payment confusion"
  # risk: residents paying the wrong account, or an unapproved collector.
  def receiving_account_approved?
    receiving_account_name.present? && receiving_account_detail.present? && approved_by.present?
  end

  def openable?
    draft? && receiving_account_approved?
  end

  def open!(by:, reason: nil)
    unless receiving_account_approved?
      raise ArgumentError,
            "a campaign cannot open until its receiving account or collector has been approved"
    end
    raise ArgumentError, "only a draft campaign can be opened" unless draft?

    self.change_reason = reason || "Campaign opened"
    update!(status: :open)
  end

  def close!(reason: nil)
    self.change_reason = reason || "Campaign closed"
    update!(status: :closed)
  end

  def approve_receiving_account!(by:, name:, detail:, reason: nil)
    self.change_reason = reason || "Receiving account approved"
    update!(receiving_account_name: name, receiving_account_detail: detail,
            approved_by: by, approved_at: Time.current)
  end

  # --- The ledger ----------------------------------------------------------
  # Only money is totalled. Materials and labour are counted, never converted to
  # a cash figure: putting a price on someone's donated labour is a judgement
  # the registry has no business making.

  def money_contributions
    contributions.where(contribution_kind: :money)
  end

  def received_amount
    money_contributions.where(status: :reconciled).sum(:amount)
  end

  def pending_amount
    money_contributions.where(status: [ :pledged, :pending ]).sum(:amount)
  end

  def exception_amount
    money_contributions.where(status: :exception).sum(:amount)
  end

  def outstanding_amount
    return nil if target_amount.blank?

    [ target_amount - received_amount, 0 ].max
  end

  def progress_percentage
    return nil if target_amount.blank? || target_amount.zero?

    ((received_amount / target_amount) * 100).round(1)
  end

  def in_kind_summary
    contributions.where.not(contribution_kind: :money)
                 .group(:contribution_kind).count
  end

  # Households asked to contribute that have not yet reconciled anything — the
  # brief's "outstanding list".
  def households_outstanding
    Household.live.where.not(
      id: contributions.where(status: :reconciled).select(:household_id)
    )
  end

  def to_s
    "#{reference} — #{name}"
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id reference name purpose campaign_type status obligation target_amount
       currency opens_on closes_on created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[contributions receipts approved_by reporting_owner]
  end

  private

  def assign_reference
    return if reference.present?

    year = Date.current.year
    last = MobilisationCampaign.where("reference LIKE ?", "CAMP-#{year}-%").order(:reference).last
    seq  = last ? last.reference.split("-").last.to_i + 1 : 1
    self.reference = format("CAMP-%d-%04d", year, seq)
  end

  def set_opens_on
    self.opens_on ||= Date.current
  end

  def closes_after_it_opens
    return if closes_on.blank? || opens_on.blank? || closes_on >= opens_on

    errors.add(:closes_on, "cannot be before the campaign opens")
  end
end
