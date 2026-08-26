ActiveAdmin.register CaseDocument do
  menu label: "Case evidence", priority: 16

  actions :all, except: [ :destroy ]

  permit_params :documentable_id, :documentable_type, :document_type,
                :file_link, :sighted_on, :note, :change_reason

  scope :all, default: true
  scope("Awaiting verification") { |s| s.recorded }
  scope("Verified")              { |s| s.verified }
  scope("Rejected")              { |s| s.rejected }

  filter :document_type, as: :select,
         collection: -> { CaseDocument.document_types.keys.map { |t| [ t.humanize, t ] } }
  filter :verification_status, as: :select,
         collection: -> { CaseDocument.verification_statuses.keys.map { |s| [ s.humanize, s ] } }
  filter :sighted_on

  csv do
    column("Case") { |d| d.documentable.try(:reference) }
    column(:document_type)
    column(:verification_status)
    column :sighted_on
    column(:uploaded_by) { |d| d.uploaded_by&.display_name }
    column(:verified_by) { |d| d.verified_by&.display_name }
    column :verified_at
    column("Stored at") { |d| d.file_link }
  end

  index do
    selectable_column
    column("Case") { |d| d.documentable.is_a?(ProgrammeCase) ? link_to(d.documentable.reference, admin_programme_case_path(d.documentable)) : d.documentable_type }
    column(:document_type) { |d| d.document_type.humanize }
    column(:verification_status) do |d|
      colour = { "verified" => :ok, "rejected" => :error, "recorded" => :warning }[d.verification_status]
      status_tag d.verification_status.humanize, class: colour
    end
    column :sighted_on
    column("Recorded by") { |d| d.uploaded_by&.display_name }
    column("Verified by") { |d| d.verified_by&.display_name }
    actions
  end

  show do
    attributes_table do
      row("Case") { |d| d.documentable.is_a?(ProgrammeCase) ? link_to(d.documentable.to_s, admin_programme_case_path(d.documentable)) : d.documentable_type }
      row(:document_type) { |d| d.document_type.humanize }
      row(:verification_status) { |d| d.verification_status.humanize }
      row :sighted_on
      row(:uploaded_by) { |d| d.uploaded_by&.display_name }
      row(:verified_by) { |d| d.verified_by&.display_name }
      row :verified_at
      row("Where it is stored") { |d| d.file_link.presence || "not linked" }
      row :note
    end

    para "The registry records that this document was sighted, not what it said. "\
         "The file itself lives in the linked storage, never in this database."

    panel "Audit trail" do
      table_for resource.audit_trail.limit(15) do
        column("When") { |v| v.created_at.strftime("%d %b %Y %H:%M") }
        column("Who")  { |v| audit_actor_label(v) }
        column("What") { |v| v.event.humanize }
        column("Reason") { |v| v.reason.presence || "—" }
      end
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs "Evidence" do
      f.input :documentable_type, as: :hidden, input_html: { value: "ProgrammeCase" }
      f.input :documentable_id, as: :select,
              collection: ProgrammeCase.open_cases.order(:reference).map { |c| [ c.to_s, c.id ] },
              label: "Case", include_blank: false
      f.input :document_type, as: :select,
              collection: CaseDocument.document_types.keys.map { |t| [ t.humanize, t ] },
              include_blank: false
      f.input :sighted_on, hint: "When it was actually seen. Defaults to today."
      f.input :file_link, label: "Where it is stored",
              hint: "A link to secure storage. Never paste the contents of a document here, "\
                    "and never upload identity document images."
      f.input :note, hint: "That it was seen and by whom — not what it contained."
    end

    f.inputs "Audit" do
      f.input :change_reason, as: :string, label: "Reason for this change"
    end

    f.actions
  end

  action_item :verify_evidence, only: :show,
              if: -> { resource.recorded? && authorized?(:verify_evidence, resource) } do
    link_to "Verify this evidence", verify_admin_case_document_path(resource),
            data: { turbo_method: :put, turbo_confirm: "Confirm you have sighted this document?" }
  end

  member_action :verify, method: :put do
    authorize! :verify_evidence, resource
    resource.verify!(by: current_user)
    redirect_to resource_path, notice: "Evidence verified."
  rescue ArgumentError => e
    redirect_to resource_path, alert: e.message
  end

  controller do
    def create
      @resource = CaseDocument.new(permitted_params[:case_document])
      @resource.uploaded_by = current_user
      super
    end
  end
end
