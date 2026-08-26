ActiveAdmin.register Contribution do
  menu label: "Contributions", priority: 21

  actions :all, except: [ :destroy ]

  permit_params :mobilisation_campaign_id, :household_id, :contribution_kind,
                :amount, :item_description, :payment_method, :payment_reference,
                :pledged_on, :change_reason

  scope :all, default: true
  scope("Outstanding")      { |s| s.outstanding }
  scope("Reconciled")       { |s| s.where(status: :reconciled) }
  scope("Exceptions")       { |s| s.needs_attention }

  filter :reference
  filter :mobilisation_campaign,
         collection: -> { MobilisationCampaign.order(:reference).map { |c| [ c.to_s, c.id ] } }
  filter :household, collection: -> { Household.live.order(:reference).map { |h| [ h.to_s, h.id ] } }
  filter :contribution_kind, as: :select,
         collection: -> { Contribution.contribution_kinds.keys.map { |k| [ k.humanize, k ] } }
  filter :status, as: :select,
         collection: -> { Contribution.statuses.keys.map { |s| [ s.humanize, s ] } }
  filter :payment_method, as: :select,
         collection: -> { Contribution.payment_methods.keys.map { |m| [ m.humanize, m ] } }
  filter :payment_reference
  filter :pledged_on

  csv do
    column :reference
    column("Campaign") { |k| k.mobilisation_campaign.reference }
    column("Household") { |k| k.household.reference }
    column(:contribution_kind)
    column :amount
    column :item_description
    column(:payment_method)
    column :payment_reference
    column(:status)
    column :exception_note
    column("Receipts verified") { |k| k.verified_receipts.count }
    column("Receipted amount") { |k| k.receipted_amount }
    column :pledged_on
    column(:recorded_by) { |k| k.recorded_by&.display_name }
  end

  index do
    selectable_column
    column :reference
    column("Campaign") { |k| link_to k.mobilisation_campaign.reference, admin_mobilisation_campaign_path(k.mobilisation_campaign) }
    column("Household") { |k| link_to k.household.reference, admin_household_path(k.household) }
    column("What") { |k| k.describes }
    column(:payment_method) { |k| k.payment_method&.humanize }
    column(:status) do |k|
      colour = { "reconciled" => :ok, "exception" => :error, "pending" => :warning, "pledged" => nil }[k.status]
      status_tag k.status.humanize, class: colour
    end
    actions
  end

  show do
    attributes_table do
      row :reference
      row("Campaign") { |k| link_to k.mobilisation_campaign.to_s, admin_mobilisation_campaign_path(k.mobilisation_campaign) }
      row("Household") { |k| link_to k.household.to_s, admin_household_path(k.household) }
      row(:contribution_kind) { |k| k.contribution_kind.humanize }
      row("What was given") { |k| k.describes }
      row(:payment_method) { |k| k.payment_method&.humanize }
      row :payment_reference
      row(:status) { |k| status_tag k.status.humanize }
      row :exception_note
      row :pledged_on
      row(:recorded_by) { |k| k.recorded_by&.display_name }
    end

    panel "Receipts" do
      para "A contribution is only reconciled against a VERIFIED receipt. "\
           "Recording that money arrived is not the same as confirming it."

      table_for resource.receipts.order(:issued_on) do
        column("Receipt") { |r| link_to r.reference, admin_receipt_path(r) }
        column(:payment_rail) { |r| r.payment_rail.humanize }
        column :external_reference
        column :amount
        column(:verification_status) do |r|
          colour = { "verified" => :ok, "rejected" => :error, "recorded" => :warning }[r.verification_status]
          status_tag r.verification_status.humanize, class: colour
        end
        column("Captured by") { |r| r.captured_by&.display_name }
        column("Verified by") { |r| r.verified_by&.display_name }
      end
    end

    panel "Audit trail" do
      table_for resource.audit_trail.limit(20) do
        column("When") { |v| v.created_at.strftime("%d %b %Y %H:%M") }
        column("Who")  { |v| audit_actor_label(v) }
        column("What") { |v| v.event.humanize }
        column("Reason") { |v| v.reason.presence || "—" }
      end
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs "Contribution" do
      f.input :mobilisation_campaign,
              collection: MobilisationCampaign.live.order(:reference).map { |c| [ c.to_s, c.id ] },
              include_blank: false,
              hint: "Only open campaigns can take contributions."
      f.input :household, collection: Household.live.order(:reference).map { |h| [ h.to_s, h.id ] },
              include_blank: false
      f.input :contribution_kind, as: :select,
              collection: Contribution.contribution_kinds.keys.map { |k| [ k.humanize, k ] },
              include_blank: false
      f.input :amount, hint: "For money contributions."
      f.input :item_description, hint: "For materials or labour, e.g. 'Two days roofing labour'."
      f.input :payment_method, as: :select,
              collection: Contribution.payment_methods.keys.map { |m| [ m.humanize, m ] },
              include_blank: "Not decided yet"
      f.input :payment_reference, hint: "The reference the rail gave the household."
      f.input :pledged_on
    end

    f.inputs "Audit" do
      f.input :change_reason, as: :string, label: "Reason for this change"
    end

    f.actions
  end

  action_item :reconcile, only: :show,
              if: -> { !resource.reconciled? && authorized?(:reconcile, resource) } do
    link_to "Reconcile", reconcile_admin_contribution_path(resource),
            data: { turbo_method: :put, turbo_confirm: "Mark this contribution as received?" }
  end

  member_action :reconcile, method: :put do
    authorize! :reconcile, resource
    resource.reconcile!
    redirect_to resource_path, notice: "Contribution reconciled."
  rescue ArgumentError => e
    redirect_to resource_path, alert: e.message
  end

  member_action :flag_exception, method: :put do
    authorize! :reconcile, resource
    resource.flag_exception!(note: params[:exception_note].presence || "Flagged for review")
    redirect_to resource_path, notice: "Recorded as an exception for follow-up."
  end

  controller do
    def create
      @resource = Contribution.new(permitted_params[:contribution])
      @resource.recorded_by = current_user
      super
    end
  end
end
