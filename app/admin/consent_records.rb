ActiveAdmin.register ConsentRecord do
  menu label: "Consent", priority: 30

  actions :all, except: [ :destroy ]

  permit_params :person_id, :purpose, :consent_version, :channel, :granted_on, :change_reason

  scope :all, default: true
  scope("Active")    { |s| s.active }
  scope("Withdrawn") { |s| s.withdrawn }
  ConsentRecord.purposes.each_key do |purpose|
    scope(purpose.humanize) { |s| s.for_purpose(purpose) }
  end

  filter :person, collection: -> { Person.active.order(:name).map { |p| [ "#{p.name} (#{p.household.reference})", p.id ] } }
  filter :purpose, as: :select, collection: -> { ConsentRecord.purposes.keys.map { |p| [ p.humanize, p ] } }
  filter :channel, as: :select, collection: -> { ConsentRecord.channels.keys.map { |c| [ c.humanize, c ] } }
  filter :consent_version
  filter :granted_on

  index do
    selectable_column
    column(:person) { |c| link_to c.person.name, admin_person_path(c.person) }
    column("Household") { |c| link_to c.person.household.reference, admin_household_path(c.person.household) }
    column(:purpose) { |c| status_tag c.purpose.humanize, class: :ok }
    column :consent_version
    column(:channel) { |c| c.channel.humanize }
    column :granted_on
    column("Status") { |c| c.withdrawn? ? status_tag("Withdrawn", class: :error) : status_tag("Active", class: :ok) }
    actions
  end

  show do
    attributes_table do
      row(:person) { |c| link_to c.person.name, admin_person_path(c.person) }
      row(:purpose) { |c| c.purpose.humanize }
      row :consent_version
      row(:channel) { |c| c.channel.humanize }
      row :granted_on
      row(:recorded_by) { |c| c.recorded_by&.display_name }
      row("Status") { |c| c.withdrawn? ? status_tag("Withdrawn", class: :error) : status_tag("Active", class: :ok) }
      row :withdrawn_at
      row :withdrawal_note
    end

    panel "Audit trail" do
      table_for resource.audit_trail.limit(15) do
        column("When") { |v| v.created_at.strftime("%d %b %Y %H:%M") }
        column("Who")  { |v| User.find_by(id: v.whodunnit)&.display_name || "system" }
        column("What") { |v| v.event.humanize }
        column("Reason") { |v| v.reason.presence || "—" }
      end
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs "Consent" do
      f.input :person, collection: Person.active.order(:name).map { |p| [ "#{p.name} (#{p.household.reference})", p.id ] }
      f.input :purpose, as: :select,
              collection: ConsentRecord.purposes.keys.map { |p| [ p.humanize, p ] },
              include_blank: false,
              hint: "Each purpose is agreed to separately. There is no blanket consent."
      f.input :consent_version, hint: "Which wording the person actually agreed to, e.g. v1."
      f.input :channel, as: :select,
              collection: ConsentRecord.channels.keys.map { |c| [ c.humanize, c ] }, include_blank: false
      f.input :granted_on
    end

    f.inputs "Audit" do
      f.input :change_reason, as: :string, label: "Reason for this change"
    end

    f.actions
  end

  action_item :withdraw, only: :show, if: -> { !resource.withdrawn? && authorized?(:withdraw, resource) } do
    link_to "Record withdrawal", withdraw_admin_consent_record_path(resource),
            data: { turbo_method: :put, turbo_confirm: "Record that this consent was withdrawn? The record is kept." }
  end

  member_action :withdraw, method: :put do
    authorize! :withdraw, resource
    resource.withdraw!(reason: "Withdrawn from the registry workspace")
    redirect_to resource_path, notice: "Withdrawal recorded. The consent record is retained."
  end

  controller do
    def create
      @resource = ConsentRecord.new(permitted_params[:consent_record])
      @resource.recorded_by = current_user
      super
    end
  end
end
