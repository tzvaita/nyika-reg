ActiveAdmin.register Receipt do
  menu label: "Receipts", priority: 22

  actions :all, except: [ :destroy ]

  permit_params :contribution_id, :payment_rail, :external_reference, :amount,
                :issued_on, :proof_link, :note, :change_reason

  scope :all, default: true
  scope("Awaiting verification") { |s| s.recorded }
  scope("Verified")              { |s| s.verified }
  scope("Rejected")              { |s| s.rejected }
  scope("Cash")                  { |s| s.where(payment_rail: :cash_collector) }

  filter :reference
  filter :external_reference
  filter :payment_rail, as: :select,
         collection: -> { Receipt.payment_rails.keys.map { |r| [ r.humanize, r ] } }
  filter :verification_status, as: :select,
         collection: -> { Receipt.verification_statuses.keys.map { |s| [ s.humanize, s ] } }
  filter :issued_on

  csv do
    column :reference
    column("Contribution") { |r| r.contribution.reference }
    column("Campaign") { |r| r.mobilisation_campaign.reference }
    column("Household") { |r| r.household.reference }
    column(:payment_rail)
    column :external_reference
    column :amount
    column :issued_on
    column(:verification_status)
    column(:captured_by) { |r| r.captured_by&.display_name }
    column(:verified_by) { |r| r.verified_by&.display_name }
    column :verified_at
  end

  index do
    selectable_column
    column :reference
    column("Contribution") { |r| link_to r.contribution.reference, admin_contribution_path(r.contribution) }
    column("Household") { |r| link_to r.household.reference, admin_household_path(r.household) }
    column(:payment_rail) do |r|
      # Cash is where money goes missing, so it is visually distinct.
      status_tag r.payment_rail.humanize, class: r.cash_collector? ? :warning : nil
    end
    column :external_reference
    column :amount
    column(:verification_status) do |r|
      colour = { "verified" => :ok, "rejected" => :error, "recorded" => :warning }[r.verification_status]
      status_tag r.verification_status.humanize, class: colour
    end
    actions
  end

  show do
    attributes_table do
      row :reference
      row("Contribution") { |r| link_to r.contribution.to_s, admin_contribution_path(r.contribution) }
      row("Campaign") { |r| link_to r.mobilisation_campaign.to_s, admin_mobilisation_campaign_path(r.mobilisation_campaign) }
      row("Household") { |r| link_to r.household.to_s, admin_household_path(r.household) }
      row(:payment_rail) { |r| r.payment_rail.humanize }
      row :external_reference
      row :amount
      row :issued_on
      row(:verification_status) { |r| status_tag r.verification_status.humanize }
      row(:captured_by) { |r| r.captured_by&.display_name }
      row(:verified_by) { |r| r.verified_by&.display_name }
      row :verified_at
      row("Proof") { |r| r.proof_link.presence || "not linked" }
      row :note
    end

    para "The registry holds the proof and the reference, never the money. "\
         "Payment happened on a licensed rail or with an authorised collector."

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

    f.inputs "Receipt" do
      f.input :contribution,
              collection: Contribution.order(created_at: :desc).limit(200).map { |k| [ "#{k.reference} — #{k.household.reference} — #{k.describes}", k.id ] },
              include_blank: false
      f.input :payment_rail, as: :select,
              collection: Receipt.payment_rails.keys.map { |r| [ r.humanize, r ] },
              include_blank: false
      f.input :external_reference, hint: "What the rail issued, e.g. an EcoCash transaction id."
      f.input :amount
      f.input :issued_on
      f.input :proof_link,
              hint: "Required for cash: a link to the banking proof or photographed slip. "\
                    "Never record card or account credentials."
      f.input :note
    end

    f.inputs "Audit" do
      f.input :change_reason, as: :string, label: "Reason for this change"
    end

    f.actions
  end

  action_item :verify_receipt, only: :show,
              if: -> { resource.recorded? && authorized?(:verify_receipt, resource) } do
    link_to "Verify this receipt", verify_admin_receipt_path(resource),
            data: { turbo_method: :put, turbo_confirm: "Confirm this payment reached the approved account?" }
  end

  member_action :verify, method: :put do
    authorize! :verify_receipt, resource
    resource.verify!(by: current_user)
    redirect_to resource_path, notice: "Receipt verified."
  rescue ArgumentError => e
    redirect_to resource_path, alert: e.message
  end

  controller do
    def create
      @resource = Receipt.new(permitted_params[:receipt])
      @resource.captured_by = current_user
      super
    end
  end
end
