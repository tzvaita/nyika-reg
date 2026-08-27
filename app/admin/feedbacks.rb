ActiveAdmin.register Feedback do
  menu label: "Have your say", priority: 12

  actions :all, except: [ :destroy ]

  permit_params :status, :response, :change_reason

  scope("Waiting", default: true) { |s| s.open_comments }
  scope :all
  scope("Responded") { |s| s.where(status: :responded) }
  scope("Closed")    { |s| s.where(status: :closed) }

  filter :category, as: :select,
         collection: -> { Feedback.categories.keys.map { |c| [ c.humanize, c ] } }
  filter :status, as: :select,
         collection: -> { Feedback.statuses.keys.map { |s| [ s.humanize, s ] } }
  filter :created_at

  FEEDBACK_STATUS_COLOURS = {
    "new_comment" => :warning, "in_review" => nil, "action_required" => :error,
    "responded" => :ok, "closed" => nil
  }.freeze

  csv do
    column("From") { |f| f.display_name }
    column("Contactable") { |f| f.contactable? }
    column(:category)
    column(:status)
    column :message
    column :response
    column :created_at
    column(:handled_by) { |f| f.handled_by&.display_name }
    column :handled_at
  end

  index do
    selectable_column
    column("From") { |f| f.anonymous? ? em("Anonymous") : f.name }
    column(:category) { |f| f.category.humanize }
    column("Comment") { |f| truncate(f.message, length: 90) }
    column(:status) { |f| status_tag f.status.humanize, class: FEEDBACK_STATUS_COLOURS[f.status] }
    column("Waiting") { |f| "#{(Date.current - f.created_at.to_date).to_i} days" }
    actions
  end

  show do
    attributes_table do
      row("From") { |f| f.anonymous? ? "Anonymous" : f.name }
      row("Reply to") do |f|
        f.contactable? ? f.contact_method : "no contact given — answer at a village meeting"
      end
      row(:category) { |f| f.category.humanize }
      row(:status) { |f| status_tag f.status.humanize, class: FEEDBACK_STATUS_COLOURS[f.status] }
      row :message
      row :response
      row(:handled_by) { |f| f.handled_by&.display_name }
      row :handled_at
      row :created_at
    end

    para "Comments may be sent anonymously. A complaint that can only be made " \
         "under a name is not really an open channel, so an anonymous comment " \
         "is worth the same attention as a signed one."

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

    f.inputs "Handling" do
      f.input :status, as: :select,
              collection: Feedback.statuses.keys.map { |s| [ s.humanize, s ] },
              include_blank: false
      f.input :response, as: :text,
              hint: "What was said back, or what was done about it."
    end

    f.inputs "Audit" do
      f.input :change_reason, as: :string, label: "Reason for this change"
    end

    f.actions
  end

  action_item :take_up, only: :show, if: -> { resource.new_comment? && authorized?(:update, resource) } do
    link_to "Take this up", take_up_admin_feedback_path(resource), data: { turbo_method: :put }
  end

  member_action :take_up, method: :put do
    authorize! :update, resource
    resource.mark_in_review!(by: current_user)
    redirect_to resource_path, notice: "Marked as being looked at."
  end
end
