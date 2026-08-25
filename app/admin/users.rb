ActiveAdmin.register User do
  menu label: "Users", priority: 90

  # No :destroy — users are the actors recorded in the audit trail, so accounts are
  # deactivated (active: false), never deleted.
  actions :all, except: [ :destroy ]

  permit_params :email, :name, :role, :active, :password, :password_confirmation

  filter :name
  filter :email
  filter :role, as: :select, collection: -> { User.roles.keys.map { |r| [ r.humanize, r ] } }
  filter :active
  filter :created_at

  scope :all, default: true
  scope("Active") { |scope| scope.where(active: true) }
  scope("Deactivated") { |scope| scope.where(active: false) }

  User.roles.each_key do |role_name|
    scope(role_name.humanize) { |scope| scope.where(role: role_name) }
  end

  index do
    selectable_column
    id_column
    column :name
    column :email
    column(:role) { |user| status_tag user.role.humanize, class: user.tech_admin? ? :error : :ok }
    column(:active) { |user| status_tag(user.active? ? "Active" : "Deactivated", class: user.active? ? :ok : :error) }
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :name
      row :email
      row(:role) { |user| user.role.humanize }
      row(:active) { |user| user.active? ? "Active" : "Deactivated" }
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs "Account" do
      f.input :name
      f.input :email
      f.input :role, as: :select,
                     collection: User.roles.keys.map { |r| [ r.humanize, r ] },
                     include_blank: false
      f.input :active, hint: "Deactivated users keep their audit history but cannot sign in."
    end

    f.inputs "Password" do
      if f.object.persisted?
        para "Leave blank to keep the current password.", class: "hint"
      end
      f.input :password
      f.input :password_confirmation
    end

    f.actions
  end

  controller do
    # Devise requires the password fields to be absent (not blank) on update,
    # otherwise validation rejects an unchanged password.
    def update
      if params[:user][:password].blank?
        params[:user].delete(:password)
        params[:user].delete(:password_confirmation)
      end
      super
    end
  end
end
