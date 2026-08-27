class Feedback < ApplicationRecord
  include Auditable

  enum :category, {
    village_services: 0,
    programmes: 1,
    payments: 2,
    the_register: 3,
    something_else: 4
  }, validate: true

  # The same words the concept deck uses, so the admin and the public page can
  # never describe the same thing differently.
  enum :status, {
    new_comment: 0,
    in_review: 1,
    action_required: 2,
    responded: 3,
    closed: 4
  }, validate: true

  belongs_to :handled_by, class_name: "User", optional: true

  validates :message, presence: true, length: { maximum: 4000 }

  scope :open_comments, -> { where(status: [ :new_comment, :in_review, :action_required ]) }

  def anonymous?
    name.blank?
  end

  def display_name
    name.presence || "Anonymous"
  end

  # Whether we can actually reply. Plenty of comments are anonymous by choice,
  # and those are answered at a village meeting rather than personally.
  def contactable?
    contact_method.present?
  end

  def mark_in_review!(by:, reason: nil)
    self.change_reason = reason || "Taken up for review"
    update!(status: :in_review, handled_by: by, handled_at: Time.current)
  end

  def respond!(by:, response:, reason: nil)
    self.change_reason = reason || "Responded"
    update!(status: :responded, response: response, handled_by: by,
            handled_at: Time.current)
  end

  def close!(by:, reason:)
    self.change_reason = reason
    update!(status: :closed, handled_by: by, handled_at: Time.current)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name category status created_at handled_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[handled_by]
  end
end
