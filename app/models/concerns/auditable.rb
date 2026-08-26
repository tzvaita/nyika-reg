# Immutable audit trail for registry records.
#
# Every including model records actor (whodunnit), timestamp, old and new values,
# a free-text reason and the source channel on each change. Records are never
# destroyed — models use a status flip or an `active` flag instead — so the version
# history always has a live record to point at.
module Auditable
  extend ActiveSupport::Concern

  # Where a change came from. Recorded on every version so assisted edits can be
  # told apart from ones a household made itself.
  SOURCE_CHANNELS = %w[admin assisted resident_link seed system].freeze

  included do
    # Both are set on the instance before saving and stored on the version row.
    attr_accessor :change_reason
    attr_writer :audit_source_channel

    has_paper_trail meta: {
      reason: :change_reason,
      source_channel: :audit_source_channel
    }
  end

  # Defaults to "system" so a version is never written without a channel — an
  # unlabelled row would silently distort the pilot's update-rate figure.
  def audit_source_channel
    @audit_source_channel.presence || PaperTrail.request.controller_info&.dig(:source_channel) || "system"
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
