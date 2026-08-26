# Immutable audit trail for registry records.
#
# Every including model records actor (whodunnit), timestamp, old and new values,
# and a free-text reason on each change. Records are never destroyed — models use
# a status flip or an `active` flag instead — so the version history always has a
# live record to point at.
module Auditable
  extend ActiveSupport::Concern

  included do
    # Set on the instance before saving; stored on the version row.
    attr_accessor :change_reason

    has_paper_trail meta: { reason: :change_reason }
  end

  # The audit history, newest first.
  def audit_trail
    versions.reorder(created_at: :desc, id: :desc)
  end

  # Who last touched this record, resolved from whodunnit.
  def last_edited_by
    id = versions.last&.whodunnit
    User.find_by(id: id) if id.present?
  end
end
