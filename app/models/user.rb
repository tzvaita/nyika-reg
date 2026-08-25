class User < ApplicationRecord
  # No :registerable — accounts are provisioned by an administrator, never by
  # public self-signup. Every user is a known village-level actor.
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  # The four roles from the brief. Ordinals are frozen: they are persisted as
  # integers, so never reorder or remove a value — append only.
  enum :role, {
    registrar: 0,          # captures and edits households
    administrator: 1,      # verifies households, manages users
    programme_manager: 2,  # read-only reporting across the registry
    tech_admin: 3          # system administration, the only soft-delete role
  }, validate: true

  validates :name, presence: true

  scope :active, -> { where(active: true) }

  # Devise: a deactivated user keeps their audit history but cannot sign in.
  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :account_deactivated
  end

  # Ransack (ActiveAdmin's search/filter layer) requires an explicit allowlist.
  # Keeping it explicit is deliberate: credential columns such as
  # encrypted_password and reset_password_token must never be searchable.
  def self.ransackable_attributes(_auth_object = nil)
    %w[id name email role active created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def display_name
    name.presence || email
  end

  def to_s
    display_name
  end
end
