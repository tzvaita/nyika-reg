# Request-scoped defaults.
#
# The audit channel lives here rather than in PaperTrail's controller_info
# because controller_info is merged into the version AFTER the model's own
# metadata, which silently overrode any channel a model set for itself. A
# request-level default that a record can override is the behaviour we want, and
# this gives it that order.
class Current < ActiveSupport::CurrentAttributes
  attribute :audit_source_channel
end
