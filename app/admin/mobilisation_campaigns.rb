ActiveAdmin.register MobilisationCampaign do
  menu label: "Campaigns", priority: 20

  actions :all, except: [ :destroy ]

  permit_params :name, :purpose, :campaign_type, :obligation, :target_amount,
                :currency, :target_description, :suggested_contribution,
                :opens_on, :closes_on, :reporting_owner_id, :change_reason

  scope :all, default: true
  scope("Open")   { |s| s.live }
  scope("Draft")  { |s| s.where(status: :draft) }
  scope("Closed") { |s| s.where(status: :closed) }

  filter :reference
  filter :name
  filter :campaign_type, as: :select,
         collection: -> { MobilisationCampaign.campaign_types.keys.map { |t| [ t.humanize, t ] } }
  filter :status, as: :select,
         collection: -> { MobilisationCampaign.statuses.keys.map { |s| [ s.humanize, s ] } }
  filter :obligation, as: :select,
         collection: -> { MobilisationCampaign.obligations.keys.map { |o| [ o.humanize, o ] } }
  filter :opens_on

  # The campaign ledger the brief lists as a required deliverable.
  csv do
    column :reference
    column :name
    column(:campaign_type)
    column(:status)
    column(:obligation)
    column :currency
    column :target_amount
    column("Received") { |c| c.received_amount }
    column("Pending") { |c| c.pending_amount }
    column("In exception") { |c| c.exception_amount }
    column("Outstanding") { |c| c.outstanding_amount }
    column("Progress %") { |c| c.progress_percentage }
    column("Contributions") { |c| c.contributions.count }
    column("Households yet to reconcile") { |c| c.households_outstanding.count }
    column :receiving_account_name
    column(:approved_by) { |c| c.approved_by&.display_name }
    column :opens_on
    column :closes_on
  end

  index do
    selectable_column
    column :reference
    column :name
    column(:campaign_type) { |c| c.campaign_type.humanize }
    column(:status) do |c|
      status_tag c.status.humanize,
                 class: { "open" => :ok, "draft" => :warning, "closed" => nil }[c.status]
    end
    column(:obligation) do |c|
      status_tag c.obligation.humanize, class: c.approved_obligation? ? :warning : :ok
    end
    column("Target") { |c| c.target_amount ? "#{c.currency} #{c.target_amount}" : c.target_description }
    column("Received") { |c| c.target_amount ? "#{c.currency} #{c.received_amount} (#{c.progress_percentage}%)" : "—" }
    actions
  end

  show do
    panel "Campaign" do
      attributes_table_for resource do
        row :reference
        row :name
        row :purpose
        row(:campaign_type) { |c| c.campaign_type.humanize }
        row(:status) { |c| status_tag c.status.humanize }
        row(:obligation) do |c|
          c.approved_obligation? ?
            status_tag("Approved obligation", class: :warning) :
            status_tag("Voluntary", class: :ok)
        end
        row("Target") { |c| c.target_amount ? "#{c.currency} #{c.target_amount}" : c.target_description }
        row("Suggested contribution") { |c| c.suggested_contribution ? "#{c.currency} #{c.suggested_contribution}" : "—" }
        row :opens_on
        row :closes_on
        row(:reporting_owner) { |c| c.reporting_owner&.display_name }
      end
    end

    panel "Where money is to go" do
      # The mitigation for residents paying the wrong account. A campaign cannot
      # open without this, and it is shown prominently because a resident being
      # told the wrong account is the failure this prevents.
      if resource.receiving_account_approved?
        attributes_table_for resource do
          row :receiving_account_name
          row :receiving_account_detail
          row(:approved_by) { |c| c.approved_by&.display_name }
          row :approved_at
        end
      else
        para "No approved receiving account or collector yet. The campaign cannot "\
             "open, and no contributions can be recorded against it, until one is set."
      end
    end

    panel "Ledger" do
      # The registry reconciles; it does not hold funds. These figures describe
      # money that moved through a licensed rail or an authorised collector.
      table_for [ resource ] do
        column("Target") { |c| c.target_amount ? "#{c.currency} #{c.target_amount}" : "—" }
        column("Received") { |c| "#{c.currency} #{c.received_amount}" }
        column("Pending") { |c| "#{c.currency} #{c.pending_amount}" }
        column("Exceptions") { |c| status_tag("#{c.currency} #{c.exception_amount}", class: c.exception_amount.positive? ? :error : :ok) }
        column("Outstanding") { |c| c.outstanding_amount ? "#{c.currency} #{c.outstanding_amount}" : "—" }
        column("Progress") { |c| c.progress_percentage ? "#{c.progress_percentage}%" : "—" }
      end

      if resource.in_kind_summary.any?
        para "Materials and labour are counted, not priced: "\
             "#{resource.in_kind_summary.map { |kind, count| "#{count} #{kind.humanize.downcase}" }.to_sentence}."
      end
    end

    panel "Contributions" do
      table_for resource.contributions.order(created_at: :desc) do
        column("Reference") { |k| link_to k.reference, admin_contribution_path(k) }
        column("Household") { |k| link_to k.household.reference, admin_household_path(k.household) }
        column("What") { |k| k.describes }
        column("Method") { |k| k.payment_method&.humanize }
        column("Status") do |k|
          colour = { "reconciled" => :ok, "exception" => :error, "pending" => :warning, "pledged" => nil }[k.status]
          status_tag k.status.humanize, class: colour
        end
      end
    end

    panel "Households yet to reconcile a contribution" do
      table_for resource.households_outstanding.limit(25) do
        column("Household") { |h| link_to h.reference, admin_household_path(h) }
        column(:name)
        column(:status) { |h| h.status.humanize }
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

    f.inputs "Campaign" do
      f.input :name
      f.input :purpose
      f.input :campaign_type, as: :select,
              collection: MobilisationCampaign.campaign_types.keys.map { |t| [ t.humanize, t ] },
              include_blank: false,
              hint: "Political fundraising is deliberately not an option: it is excluded "\
                    "from this build until legal and governance approvals are explicit."
      f.input :obligation, as: :select,
              collection: MobilisationCampaign.obligations.keys.map { |o| [ o.humanize, o ] },
              include_blank: false,
              hint: "Residents must be told whether contributing is voluntary or required."
      f.input :target_amount, hint: "For a money campaign."
      f.input :currency
      f.input :suggested_contribution
      f.input :target_description, hint: "For materials or labour, e.g. '40 roof sheets'."
      f.input :opens_on
      f.input :closes_on
      f.input :reporting_owner, collection: User.active.map { |u| [ u.display_name, u.id ] },
              include_blank: true
    end

    f.inputs "Audit" do
      f.input :change_reason, as: :string, label: "Reason for this change"
    end

    f.actions
  end

  action_item :open_campaign, only: :show,
              if: -> { resource.draft? && authorized?(:open_campaign, resource) } do
    link_to "Open for contributions", open_admin_mobilisation_campaign_path(resource),
            data: { turbo_method: :put, turbo_confirm: "Open this campaign for contributions?" }
  end

  action_item :close_campaign, only: :show,
              if: -> { resource.open? && authorized?(:close_campaign, resource) } do
    link_to "Close campaign", close_admin_mobilisation_campaign_path(resource),
            data: { turbo_method: :put, turbo_confirm: "Close this campaign?" }
  end

  member_action :open, method: :put do
    authorize! :open_campaign, resource
    resource.open!(by: current_user)
    redirect_to resource_path, notice: "Campaign open for contributions."
  rescue ArgumentError => e
    redirect_to resource_path, alert: e.message
  end

  member_action :close, method: :put do
    authorize! :close_campaign, resource
    resource.close!
    redirect_to resource_path, notice: "Campaign closed."
  end

  member_action :approve_account, method: :put do
    authorize! :approve_account, resource
    resource.approve_receiving_account!(by: current_user,
                                        name: params[:receiving_account_name],
                                        detail: params[:receiving_account_detail])
    redirect_to resource_path, notice: "Receiving account approved."
  end
end
