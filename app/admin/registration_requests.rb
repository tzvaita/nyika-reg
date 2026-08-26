ActiveAdmin.register RegistrationRequest do
  menu label: "Registration requests", priority: 11

  actions :all, except: [ :destroy ]

  permit_params :name, :contact_method, :location_hint, :note, :status,
                :outcome_note, :change_reason

  scope("Waiting", default: true) { |s| s.open_requests }
  scope :all
  scope("Captured") { |s| s.where(status: :captured) }
  scope("Declined") { |s| s.where(status: :declined) }

  filter :name
  filter :contact_method
  filter :status, as: :select,
         collection: -> { RegistrationRequest.statuses.keys.map { |s| [ s.humanize, s ] } }
  filter :created_at

  csv do
    column :name
    column :contact_method
    column :location_hint
    column(:status)
    column :created_at
    column(:handled_by) { |r| r.handled_by&.display_name }
    column :handled_at
    column("Household") { |r| r.household&.reference }
  end

  index do
    selectable_column
    column :name
    column("How to reach them") { |r| r.contact_method.presence || r.location_hint }
    column(:status) do |r|
      colour = { "new_request" => :warning, "contacted" => nil,
                 "captured" => :ok, "declined" => :error }[r.status]
      status_tag r.status.humanize, class: colour
    end
    column("Waiting") { |r| "#{(Date.current - r.created_at.to_date).to_i} days" }
    column("Household") { |r| r.household ? link_to(r.household.reference, admin_household_path(r.household)) : "—" }
    actions
  end

  show do
    attributes_table do
      row :name
      row :contact_method
      row :location_hint
      row :note
      row(:status) { |r| status_tag r.status.humanize }
      row :created_at
      row(:handled_by) { |r| r.handled_by&.display_name }
      row :handled_at
      row :outcome_note
      row("Household") { |r| r.household ? link_to(r.household.to_s, admin_household_path(r.household)) : "not captured yet" }
      row("Past retention?") do |r|
        r.stale? ? status_tag("Yes — should be removed", class: :error) : status_tag("No", class: :ok)
      end
    end

    para "This is a request, not a registry record. Nothing about this household "\
         "exists in the register until a registrar has visited, explained what "\
         "registration means, taken consent and captured it."

    panel "Audit trail" do
      table_for resource.audit_trail.limit(15) do
        column("When") { |v| v.created_at.strftime("%d %b %Y %H:%M") }
        column("Who")  { |v| audit_actor_label(v) }
        column("What") { |v| v.event.humanize }
        column("Reason") { |v| v.reason.presence || "—" }
        column("Channel") { |v| audit_channel_label(v) }
      end
    end
  end

  action_item :contacted, only: :show,
              if: -> { resource.new_request? && authorized?(:update, resource) } do
    link_to "Mark as contacted", contacted_admin_registration_request_path(resource),
            data: { turbo_method: :put }
  end

  action_item :capture, only: :show,
              if: -> { !resource.captured? && authorized?(:create, Household) } do
    link_to "Capture this household", new_capture_household_path,
            class: "button"
  end

  member_action :contacted, method: :put do
    authorize! :update, resource
    resource.mark_contacted!(by: current_user)
    redirect_to resource_path, notice: "Marked as contacted."
  end

  member_action :decline, method: :put do
    authorize! :update, resource
    resource.decline!(by: current_user, note: params[:outcome_note].presence || "Not proceeding")
    redirect_to resource_path, notice: "Request closed."
  end
end
