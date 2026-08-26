# The pilot's evidence pack: data quality and operating workload.
#
# Not an ActiveRecord model — a plain query object so the ActiveAdmin page, the
# CSV exports and the rake task all report the same numbers rather than each
# recomputing them slightly differently.
#
# The metrics come from the concept deck's POC success measures: capture time,
# verification load, update rate ("how many residents can update without
# assistance") and data quality (duplicates, corrections, missing fields).
class PilotReport
  # Two households are treated as possibly the same when their name and location
  # match, ignoring case and surrounding whitespace. Backed by the
  # index_households_on_name_and_location index.
  def duplicate_household_groups
    Household.live
             .group_by { |h| [ normalise(h.name), normalise(h.location_description) ] }
             .values
             .select { |group| group.size > 1 }
  end

  def households_missing_fields
    Household.live.map { |h| [ h, h.missing_required_fields ] }
             .reject { |_, missing| missing.empty? }
  end

  def households_without_members
    Household.live.select { |h| h.active_people.none? }
  end

  def people_without_consent
    Person.active.select { |p| p.consent_records.active.none? }
  end

  # Consent is reported per purpose because there is no single consent figure to
  # report — that is the whole point of purpose-specific consent.
  def consent_by_purpose
    ConsentRecord.purposes.keys.map do |purpose|
      {
        purpose: purpose,
        active: ConsentRecord.active.for_purpose(purpose).count,
        withdrawn: ConsentRecord.withdrawn.for_purpose(purpose).count
      }
    end
  end

  # Deck: "Capture time — average minutes per household". Measured from the
  # household being created to it being submitted for verification.
  def average_capture_minutes
    average_minutes(status_transition_pairs(from_event: :created, to_status: "pending"))
  end

  # Deck: "Verification load — admin minutes per verification". Measured from
  # submission to an administrator confirming it.
  def average_verification_minutes
    average_minutes(status_transition_pairs(from_status: "pending", to_status: "verified"))
  end

  # Deck: "Update rate — how many residents can update without assistance".
  # This is what source_channel exists for.
  def update_rate
    counts = PaperTrail::Version.where(event: "update").group(:source_channel).count
    resident = counts["resident_link"].to_i
    assisted = counts["assisted"].to_i + counts["admin"].to_i
    total    = resident + assisted

    {
      resident: resident,
      assisted: assisted,
      total: total,
      percentage: total.zero? ? 0.0 : ((resident.to_f / total) * 100).round(1)
    }
  end

  # Deck p11: "Case completion — cases opened, evidence received and outcomes
  # logged". Reported separately from the registry counts because a case is a
  # different kind of fact about a household.
  def case_rows
    [
      [ "Cases opened", ProgrammeCase.count ],
      [ "Awaiting consent or evidence", ProgrammeCase.awaiting_action.count ],
      [ "Ready to submit", ProgrammeCase.submission_queue.count ],
      [ "Submitted to a programme", ProgrammeCase.where(status: :submitted).count ],
      [ "Closed with an outcome", ProgrammeCase.where(status: :closed).count ],
      [ "Evidence recorded", CaseDocument.count ],
      [ "Evidence verified", CaseDocument.verified.count ],
      [ "Cases blocked only by missing consent",
        ProgrammeCase.open_cases.count { |c| c.people_missing_consent.any? } ]
    ]
  end

  def cases_by_outcome
    ProgrammeCase.outcomes.keys.map do |outcome|
      { outcome: outcome, count: ProgrammeCase.where(outcome: outcome).count }
    end
  end

  def summary_rows
    [
      [ "Households registered", Household.live.count ],
      [ "Verified", Household.verified.count ],
      [ "Awaiting verification", Household.verification_queue.count ],
      [ "Still in capture", Household.capture_queue.count ],
      [ "People recorded", Person.active.count ],
      [ "Consent records", ConsentRecord.count ],
      [ "Households missing required fields", households_missing_fields.size ],
      [ "Households with no members", households_without_members.size ],
      [ "People with no consent recorded", people_without_consent.size ],
      [ "Possible duplicate households", duplicate_household_groups.sum(&:size) ],
      [ "Average capture time (minutes)", average_capture_minutes || "not enough data" ],
      [ "Average verification time (minutes)", average_verification_minutes || "not enough data" ],
      [ "Resident-made updates (%)", update_rate[:percentage] ]
    ]
  end

  private

  def normalise(value)
    value.to_s.downcase.strip.gsub(/\s+/, " ")
  end

  # Walks each household's versions to find when it entered a status, so the
  # timings come from the audit trail rather than needing extra columns.
  def status_transition_pairs(from_event: nil, from_status: nil, to_status:)
    Household.find_each.filter_map do |household|
      versions = household.versions.order(:created_at)

      start_at =
        if from_event == :created
          versions.first&.created_at
        else
          versions.find { |v| changed_to?(v, from_status) }&.created_at
        end

      finish_at = versions.find { |v| changed_to?(v, to_status) }&.created_at

      next if start_at.nil? || finish_at.nil? || finish_at < start_at

      finish_at - start_at
    end
  end

  # PaperTrail serialises enums as their stored INTEGER, not the name, so a
  # version records status going 0 -> 1 rather than "draft" -> "pending".
  # Compare against both so this keeps working if the serialiser ever changes.
  def changed_to?(version, status)
    return false if version.object_changes.blank?

    changes = YAML.unsafe_load(version.object_changes)
    status_change = changes["status"]
    return false if status_change.blank?

    new_value = status_change.last
    new_value.to_s == status.to_s || new_value == Household.statuses[status.to_s]
  rescue StandardError
    false
  end

  def average_minutes(durations)
    return nil if durations.empty?

    ((durations.sum / durations.size) / 60.0).round(1)
  end
end
