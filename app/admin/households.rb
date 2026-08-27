ActiveAdmin.register Household do
  menu label: "Households", priority: 10

  # No :destroy — registry records are deactivated, never deleted.
  actions :all, except: [ :destroy ]

  permit_params :name, :principal_contact, :location_description,
                :capture_source, :last_confirmed_on, :change_reason

  # The queues from the brief.
  scope :all, default: true
  scope("Capture queue")      { |s| s.capture_queue }
  scope("Verification queue") { |s| s.verification_queue }
  scope("Verified")           { |s| s.where(status: :verified) }
  scope("Inactive")           { |s| s.where(status: :inactive) }

  filter :reference
  filter :name
  filter :principal_contact
  filter :location_description
  filter :status, as: :select, collection: -> { Household.statuses.keys.map { |s| [ s.humanize, s ] } }
  filter :capture_source, as: :select, collection: -> { Household.capture_sources.keys.map { |s| [ s.humanize, s ] } }
  filter :created_at

  HOUSEHOLD_STATUS_COLOURS = { "draft" => :orange, "pending" => :warning,
                     "verified" => :ok, "inactive" => :error }.freeze

  index do
    selectable_column
    column :reference
    column :name
    column(:status) { |h| status_tag h.status.humanize, class: HOUSEHOLD_STATUS_COLOURS[h.status] }
    column :principal_contact
    column("Members") { |h| h.active_people.count }
    column("Complete") { |h| h.complete? ? status_tag("Yes", class: :ok) : status_tag(h.missing_required_fields.map(&:humanize).join(", "), class: :error) }
    column :last_confirmed_on
    actions
  end

  # Pilot summary export. Deliberately excludes the resident token — a CSV gets
  # mailed around, and every token in it is a working key to that household.
  csv do
    column :reference
    column :name
    column :status
    column :principal_contact
    column :location_description
    column(:capture_source) { |h| h.capture_source }
    column("Members") { |h| h.active_people.count }
    column("Missing fields") { |h| h.missing_required_fields.join(" ") }
    column("Complete") { |h| h.complete? }
    column(:captured_by) { |h| h.captured_by&.display_name }
    column(:verified_by) { |h| h.verified_by&.display_name }
    column :verified_at
    column :last_confirmed_on
    column :created_at
    ConsentRecord.purposes.keys.each do |purpose|
      column("Consent: #{purpose.humanize}") do |household|
        household.active_people.count { |person| person.consented_to?(purpose) }
      end
    end
  end

  show do
    panel "Household" do
      attributes_table_for resource do
        row :reference
        row :name
        row(:status) { |h| status_tag h.status.humanize, class: HOUSEHOLD_STATUS_COLOURS[h.status] }
        row :principal_contact
        row("Reachable by message") do |h|
          h.contact_number.presence ||
            status_tag("no number on record", class: :warning)
        end
        row :location_description
        row(:capture_source) { |h| h.capture_source.humanize }
        row :last_confirmed_on
        row(:captured_by) { |h| h.captured_by&.display_name }
        row(:verified_by) { |h| h.verified_by&.display_name }
        row :verified_at
      end
    end

    panel "Household sign-in" do
      attributes_table_for resource do
        row("Signs in with") { |h| h.contact_number.presence || status_tag("no number on record", class: :warning) }
        row("PIN") do |h|
          if !h.pin_set?
            status_tag("not issued — this household cannot sign in", class: :warning)
          elsif h.pin_temporary?
            status_tag("temporary — they must replace it on first sign-in", class: :warning)
          else
            status_tag("set by the household", class: :ok)
          end
        end
        row("PIN issued by") { |h| h.pin_issued_by&.display_name }
        row("Locked") do |h|
          h.pin_locked? ? status_tag("locked until #{h.pin_locked_until.strftime('%H:%M')}", class: :error) : "no"
        end
      end
      para "PINs are given out in person and never shown again. If a household " \
           "forgets theirs, issue a new one — there is deliberately no way to " \
           "reset a PIN from a phone number alone."
    end

    panel "Resident link" do
      div do
        if resource.pin_set?
          para "Send this so the household can reach their own record quickly. " \
               "Opening it asks for their PIN, so the link on its own is not " \
               "enough to see anything — it fills in their number and no more."
        else
          para "This household has NO PIN yet, so this link opens their record on " \
               "its own. Issue a PIN above to change that."
        end
      end
      div style: "margin-top:0.75rem;font-family:monospace;word-break:break-all;" do
        household_update_url(token: resource.token, host: request.host_with_port)
      end
    end

    panel "Members (#{resource.active_people.count})" do
      table_for resource.active_people.order(:relationship) do
        column(:name) { |p| link_to p.name, admin_person_path(p) }
        column(:relationship) { |p| p.relationship.humanize }
        column("Age") { |p| p.age_band&.humanize || p.year_of_birth }
        column(:residency_status) { |p| p.residency_status.humanize }
        column("Consent given for") do |p|
          given = ConsentRecord.purposes.keys.select { |purpose| p.consented_to?(purpose) }
          given.any? ? given.map(&:humanize).join(", ") : "none recorded"
        end
      end
    end

    panel "Audit trail" do
      # Read-only by design: this is what makes the registry accountable.
      table_for resource.audit_trail.limit(25) do
        column("When") { |v| v.created_at.strftime("%d %b %Y %H:%M") }
        column("Who")  { |v| audit_actor_label(v) }
        column("What") { |v| v.event.humanize }
        column("Reason") { |v| v.reason.presence || "—" }
        column("Channel") { |v| audit_channel_label(v) }
        column("Changed") do |v|
          changes = v.object_changes ? YAML.unsafe_load(v.object_changes).keys - %w[updated_at] : []
          changes.map(&:humanize).join(", ")
        end
      end
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs "Household" do
      f.input :name
      f.input :principal_contact
      f.input :location_description,
              hint: "How to find the homestead in words. Not GPS, not a plot number."
      f.input :capture_source, as: :select,
              collection: Household.capture_sources.keys.map { |s| [ s.humanize, s ] },
              include_blank: false
      f.input :last_confirmed_on
    end

    f.inputs "Audit" do
      f.input :change_reason, as: :string,
              label: "Reason for this change",
              hint: "Recorded in the audit trail. Required for every edit."
    end

    f.actions
  end

  # --- Queue actions -------------------------------------------------------
  # Each is guarded by the Ability class; the buttons only appear to roles that
  # may use them.

  action_item :submit, only: :show, if: -> { resource.draft? && authorized?(:submit_for_verification, resource) } do
    link_to "Submit for verification", submit_admin_household_path(resource),
            method: :put, data: { turbo_method: :put, turbo_confirm: "Submit this household for verification?" }
  end

  action_item :verify, only: :show, if: -> { resource.pending? && authorized?(:verify, resource) } do
    link_to "Mark verified", verify_admin_household_path(resource),
            method: :put, data: { turbo_method: :put, turbo_confirm: "Confirm this household has been verified?" }
  end

  action_item :deactivate, only: :show, if: -> { !resource.inactive? && authorized?(:deactivate, resource) } do
    link_to "Deactivate", deactivate_admin_household_path(resource),
            method: :put, data: { turbo_method: :put, turbo_confirm: "Deactivate this household? The record is kept, not deleted." }
  end

  action_item :regenerate_token, only: :show, if: -> { authorized?(:update, resource) } do
    link_to "Regenerate resident link", regenerate_token_admin_household_path(resource),
            data: { turbo_method: :put,
                    turbo_confirm: "Regenerate the link? The household's current link will stop working immediately." }
  end

  member_action :submit, method: :put do
    authorize! :submit_for_verification, resource
    resource.submit_for_verification!(reason: "Submitted from the registry workspace")
    redirect_to resource_path, notice: "Submitted for verification."
  end

  action_item :issue_pin, only: :show, if: -> { authorized?(:update, resource) } do
    link_to(resource.pin_set? ? "Issue a new PIN" : "Issue a PIN",
            issue_pin_admin_household_path(resource),
            data: { turbo_method: :put,
                    turbo_confirm: resource.pin_set? ?
                      "Issue a new PIN? The household's current one stops working immediately." :
                      "Generate a PIN for this household?" })
  end

  # The PIN is GENERATED rather than typed, so nobody issues 123456 across half
  # the village, and it is shown ONCE for the registrar to write down and hand
  # over. After this only the digest exists — the office cannot look it up again.
  member_action :issue_pin, method: :put do
    authorize! :update, resource
    generated = resource.issue_temporary_pin!(by: current_user)

    redirect_to resource_path,
                notice: "PIN for #{resource.reference}: #{generated} — write it down and give " \
                        "it to the household. It cannot be shown again, and they must " \
                        "replace it when they first sign in."
  end

  # Revoking a leaked link. The token is a bearer credential, so this has to exist.
  member_action :regenerate_token, method: :put do
    authorize! :update, resource
    resource.regenerate_token!
    redirect_to resource_path,
                notice: "New resident link generated. The previous one no longer works."
  end

  member_action :verify, method: :put do
    authorize! :verify, resource
    resource.verify!(by: current_user, reason: "Verified from the registry workspace")
    redirect_to resource_path, notice: "Household verified."
  end

  member_action :deactivate, method: :put do
    authorize! :deactivate, resource
    resource.deactivate!(reason: "Deactivated from the registry workspace")
    redirect_to resource_path, notice: "Household deactivated. The record is retained."
  end

  controller do
    def create
      @resource = Household.new(permitted_params[:household])
      @resource.captured_by = current_user
      super
    end
  end
end
