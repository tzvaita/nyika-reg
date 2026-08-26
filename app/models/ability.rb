class Ability
  include CanCan::Ability

  # Every authorisation decision in the registry is made here. Nothing else should
  # branch on user.role — if a new rule is needed, it belongs in this file.
  #
  # The four roles, in one sentence each:
  #   registrar          captures and edits households, but cannot verify its own work
  #   administrator      verifies households and manages user accounts
  #   programme_manager  reads everything, changes nothing
  #   tech_admin         administers the system; the only role that may deactivate
  def initialize(user)
    return if user.blank? || !user.active?

    # Everyone signed in can see the registry and read the audit trail. The audit
    # trail is readable by design: it is what makes the registry accountable.
    can :read, [ Household, Person, ConsentRecord ]
    can :read, PaperTrail::Version
    # ActiveAdmin authorises its own pages (the Dashboard is one), so without this
    # every role is denied the landing page.
    can :read, ActiveAdmin::Page
    can :read, ActiveAdmin::Comment
    can :create, ActiveAdmin::Comment

    case user.role.to_sym
    when :registrar         then registrar_rules
    when :administrator     then administrator_rules
    when :programme_manager then programme_manager_rules
    when :tech_admin        then tech_admin_rules
    end

    # Nothing may ever be destroyed, whatever the role. Registry records are
    # deactivated (a status or `active` flip) so the audit trail keeps a live
    # record to point at. This is declared LAST because in CanCanCan the last
    # matching rule wins — no role rule above can re-grant destroy.
    cannot :destroy, :all
  end

  private

  # Captures the registry. Can move a household draft -> pending, but NOT
  # pending -> verified: verification is a second pair of eyes, by design.
  def registrar_rules
    can [ :create, :update ], Household, status: %w[draft pending]
    can :submit_for_verification, Household, status: "draft"
    cannot :verify, Household

    can [ :create, :update ], Person
    can [ :create, :update ], ConsentRecord
    can :withdraw, ConsentRecord
  end

  # Verifies households and manages accounts. Cannot deactivate registry records:
  # that is deliberately narrower than "admin".
  def administrator_rules
    can [ :create, :update ], Household
    can :verify, Household, status: "pending"
    can :submit_for_verification, Household, status: "draft"

    can [ :create, :update ], Person
    can [ :create, :update ], ConsentRecord
    can :withdraw, ConsentRecord

    can [ :read, :create, :update ], User
  end

  # Reporting only. Explicitly cannot write anything, including consent.
  def programme_manager_rules
    cannot [ :create, :update ], [ Household, Person, ConsentRecord ]
    cannot :verify, Household
  end

  # System administration. The only role that may soft-delete, and the only one
  # that may reach ActiveAdmin's own screens.
  def tech_admin_rules
    can :manage, User
    can [ :create, :update ], [ Household, Person, ConsentRecord ]
    can :submit_for_verification, Household, status: "draft"
    can :deactivate, [ Household, Person ]
    can :withdraw, ConsentRecord
    can :manage, ActiveAdmin::Comment
  end
end
