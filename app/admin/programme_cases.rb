ActiveAdmin.register ProgrammeCase do
  menu label: "Programme cases", priority: 15

  actions :all, except: [ :destroy ]

  permit_params :household_id, :beneficiary_id, :programme_type, :opened_on, :change_reason

  scope :all, default: true
  scope("Open")            { |s| s.open_cases }
  scope("Awaiting action") { |s| s.awaiting_action }
  scope("Ready to submit") { |s| s.submission_queue }
  scope("Submitted")       { |s| s.where(status: :submitted) }
  scope("Closed")          { |s| s.where(status: :closed) }

  filter :reference
  filter :household, collection: -> { Household.live.order(:reference).map { |h| [ h.to_s, h.id ] } }
  filter :programme_type, as: :select,
         collection: -> { ProgrammeCase.programme_types.keys.map { |t| [ t.humanize, t ] } }
  filter :status, as: :select,
         collection: -> { ProgrammeCase.statuses.keys.map { |s| [ s.humanize, s ] } }
  filter :outcome, as: :select,
         collection: -> { ProgrammeCase.outcomes.keys.map { |o| [ o.humanize, o ] } }
  filter :opened_on

  CASE_STATUS_COLOURS = {
    "identified" => :orange, "awaiting_consent" => :error,
    "gathering_evidence" => :warning, "ready_to_submit" => :ok,
    "submitted" => :ok, "closed" => nil
  }.freeze

  # The case report the brief lists as a required deliverable.
  csv do
    column :reference
    column("Household") { |c| c.household.reference }
    column("Beneficiary") { |c| c.beneficiary&.name || "whole household" }
    column(:programme_type)
    column(:status)
    column("Consent in place") { |c| c.consent_present? }
    column("Evidence complete") { |c| c.evidence_complete? }
    column("Missing evidence") { |c| c.missing_document_types.join(" ") }
    column("Blockers") { |c| c.blockers.join(" | ") }
    column :opened_on
    column :submitted_at
    column(:submitted_by) { |c| c.submitted_by&.display_name }
    column(:outcome)
    column :outcome_recorded_at
  end

  index do
    selectable_column
    column :reference
    column("Household") { |c| link_to c.household.reference, admin_household_path(c.household) }
    column("Beneficiary") { |c| c.beneficiary&.name || "whole household" }
    column(:programme_type) { |c| c.programme_type.humanize }
    column(:status) { |c| status_tag c.status.humanize, class: CASE_STATUS_COLOURS[c.status] }
    column("Blocked by") do |c|
      c.blockers.any? ? status_tag("#{c.blockers.size} issue".pluralize(c.blockers.size), class: :error) : status_tag("Clear", class: :ok)
    end
    column(:outcome) { |c| c.outcome&.humanize }
    actions
  end

  show do
    panel "Case" do
      attributes_table_for resource do
        row :reference
        row(:household) { |c| link_to c.household.to_s, admin_household_path(c.household) }
        row("Beneficiary") { |c| c.beneficiary ? link_to(c.beneficiary.name, admin_person_path(c.beneficiary)) : "the whole household" }
        row(:programme_type) { |c| c.programme_type.humanize }
        row(:status) { |c| status_tag c.status.humanize, class: CASE_STATUS_COLOURS[c.status] }
        row :opened_on
        row(:opened_by) { |c| c.opened_by&.display_name }
        row :submitted_at
        row(:submitted_by) { |c| c.submitted_by&.display_name }
        row(:outcome) { |c| c.outcome&.humanize }
        row :outcome_recorded_at
        row :outcome_note
      end
    end

    panel "Before this can be submitted" do
      if resource.blockers.any?
        ul do
          resource.blockers.each { |blocker| li blocker }
        end
      else
        para "Nothing outstanding — this case can go to the programme office."
      end
    end

    panel "Basic eligibility" do
      # A prompt for a human, never a refusal: the platform does not decide
      # entitlement and does not replace government decision authority.
      if resource.eligibility_notes.any?
        para "Worth checking before submitting. These are prompts, not refusals — "\
             "the programme office decides, not this system."
        ul do
          resource.eligibility_notes.each { |note| li note }
        end
      else
        para "Nothing obvious to query."
      end
    end

    panel "Consent to be considered for programmes" do
      table_for resource.people_needing_consent do
        column("Person") { |p| link_to p.name, admin_person_path(p) }
        column("Programme consent") do |p|
          p.consented_to?(:programme) ? status_tag("Given", class: :ok) : status_tag("Not given", class: :error)
        end
      end
    end

    panel "Evidence" do
      para "Required for #{resource.programme_type.humanize}: "\
           "#{resource.required_document_types.map(&:humanize).to_sentence}."

      table_for resource.case_documents.order(:document_type) do
        column("Document") { |d| d.document_type.humanize }
        column("Status") do |d|
          colour = { "verified" => :ok, "rejected" => :error, "recorded" => :warning }[d.verification_status]
          status_tag d.verification_status.humanize, class: colour
        end
        column("Sighted") { |d| d.sighted_on }
        column("Recorded by") { |d| d.uploaded_by&.display_name }
        column("Verified by") { |d| d.verified_by&.display_name }
        column("Where it is") { |d| d.file_link.presence || "not linked" }
        column("") { |d| link_to "View", admin_case_document_path(d) }
      end
    end

    panel "Audit trail" do
      table_for resource.audit_trail.limit(20) do
        column("When") { |v| v.created_at.strftime("%d %b %Y %H:%M") }
        column("Who")  { |v| audit_actor_label(v) }
        column("What") { |v| v.event.humanize }
        column("Reason") { |v| v.reason.presence || "—" }
        column("Channel") { |v| audit_channel_label(v) }
      end
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs "Case" do
      f.input :household, collection: Household.live.order(:reference).map { |h| [ h.to_s, h.id ] }
      f.input :beneficiary,
              collection: Person.active.order(:name).map { |p| [ "#{p.name} (#{p.household.reference})", p.id ] },
              include_blank: "The whole household",
              hint: "Leave blank where the case is for the household as a whole, such as drought relief."
      f.input :programme_type, as: :select,
              collection: ProgrammeCase.programme_types.keys.map { |t| [ t.humanize, t ] },
              include_blank: false
      f.input :opened_on, hint: "Defaults to today."
    end

    f.inputs "Audit" do
      f.input :change_reason, as: :string, label: "Reason for this change"
    end

    f.actions
  end

  action_item :refresh, only: :show, if: -> { authorized?(:update, resource) && !resource.submitted? && !resource.closed? } do
    link_to "Recalculate stage", refresh_stage_admin_programme_case_path(resource),
            data: { turbo_method: :put }
  end

  action_item :submit_case, only: :show, if: -> { resource.submittable? && authorized?(:submit, resource) } do
    link_to "Submit to programme office", submit_admin_programme_case_path(resource),
            data: { turbo_method: :put, turbo_confirm: "Send this case to the programme office?" }
  end

  member_action :refresh_stage, method: :put do
    authorize! :update, resource
    resource.refresh_stage!
    redirect_to resource_path, notice: "Stage recalculated: #{resource.status.humanize}."
  end

  member_action :submit, method: :put do
    authorize! :submit, resource
    resource.submit!(by: current_user)
    redirect_to resource_path, notice: "Case submitted to the programme office."
  rescue ArgumentError => e
    redirect_to resource_path, alert: e.message
  end

  member_action :record_outcome, method: :put do
    authorize! :record_outcome, resource
    resource.record_outcome!(outcome: params[:outcome], note: params[:outcome_note])
    redirect_to resource_path, notice: "Outcome recorded."
  end

  controller do
    def create
      @resource = ProgrammeCase.new(permitted_params[:programme_case])
      @resource.opened_by = current_user
      super
    end
  end
end
