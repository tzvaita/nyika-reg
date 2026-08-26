ActiveAdmin.register Person do
  menu label: "People", priority: 20

  actions :all, except: [ :destroy ]

  permit_params :household_id, :name, :relationship, :age_band, :year_of_birth,
                :residency_status, :contact_method, :change_reason

  scope :all, default: true
  scope("Active")   { |s| s.where(active: true) }
  scope("Inactive") { |s| s.where(active: false) }

  filter :household, collection: -> { Household.live.order(:reference).map { |h| [ h.to_s, h.id ] } }
  filter :name
  filter :relationship, as: :select, collection: -> { Person.relationships.keys.map { |r| [ r.humanize, r ] } }
  filter :age_band, as: :select, collection: -> { Person.age_bands.keys.map { |b| [ b.humanize, b ] } }
  filter :residency_status, as: :select, collection: -> { Person.residency_statuses.keys.map { |r| [ r.humanize, r ] } }
  filter :active

  # Note there is no date of birth to export: the registry does not hold one.
  csv do
    column("Household") { |p| p.household.reference }
    column :name
    column(:relationship)
    column(:age_band)
    column :year_of_birth
    column(:residency_status)
    column :contact_method
    column :active
    ConsentRecord.purposes.keys.each do |purpose|
      column("Consent: #{purpose.humanize}") { |person| person.consented_to?(purpose) }
    end
  end

  index do
    selectable_column
    column(:name) { |p| link_to p.name, admin_person_path(p) }
    column(:household) { |p| link_to p.household.reference, admin_household_path(p.household) }
    column(:relationship) { |p| p.relationship.humanize }
    column("Age") { |p| p.age_band&.humanize || p.year_of_birth || "not recorded" }
    column(:residency_status) { |p| p.residency_status.humanize }
    column(:active) { |p| status_tag(p.active? ? "Active" : "Inactive", class: p.active? ? :ok : :error) }
    actions
  end

  show do
    attributes_table do
      row(:household) { |p| link_to p.household.to_s, admin_household_path(p.household) }
      row :name
      row(:relationship) { |p| p.relationship.humanize }
      # Deliberately shows a band or a year — the registry holds no full date of birth.
      row("Age") { |p| p.age_band&.humanize || p.year_of_birth || "not recorded" }
      row(:residency_status) { |p| p.residency_status.humanize }
      row :contact_method
      row(:active) { |p| status_tag(p.active? ? "Active" : "Inactive", class: p.active? ? :ok : :error) }
    end

    panel "Consent" do
      # One row per purpose, showing exactly what was and was not agreed to.
      table_for ConsentRecord.purposes.keys do
        column("Purpose") { |purpose| purpose.humanize }
        column("Status") do |purpose|
          record = resource.consent_for(purpose)
          record ? status_tag("Given", class: :ok) : status_tag("Not given", class: :error)
        end
        column("Version") { |purpose| resource.consent_for(purpose)&.consent_version }
        column("Channel") { |purpose| resource.consent_for(purpose)&.channel&.humanize }
        column("Granted on") { |purpose| resource.consent_for(purpose)&.granted_on }
      end
    end

    panel "Consent history (including withdrawn)" do
      table_for resource.consent_records.order(granted_on: :desc) do
        column(:purpose) { |c| c.purpose.humanize }
        column :consent_version
        column(:channel) { |c| c.channel.humanize }
        column :granted_on
        column("Withdrawn") { |c| c.withdrawn? ? c.withdrawn_at.strftime("%d %b %Y") : "—" }
        column("") { |c| link_to "View", admin_consent_record_path(c) }
      end
    end

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

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs "Member" do
      f.input :household, collection: Household.live.order(:reference).map { |h| [ h.to_s, h.id ] }
      f.input :name
      f.input :relationship, as: :select,
              collection: Person.relationships.keys.map { |r| [ r.humanize, r ] }, include_blank: false
      f.input :residency_status, as: :select,
              collection: Person.residency_statuses.keys.map { |r| [ r.humanize, r ] }, include_blank: false
      f.input :contact_method, hint: "Optional. How to reach them — never an ID number."
    end

    f.inputs "Age (one of the two is required)" do
      f.input :age_band, as: :select,
              collection: Person.age_bands.keys.map { |b| [ b.humanize, b ] },
              hint: "Preferred. The registry does not collect dates of birth."
      f.input :year_of_birth, hint: "Only if the household knows it."
    end

    f.inputs "Audit" do
      f.input :change_reason, as: :string, label: "Reason for this change"
    end

    f.actions
  end
end
