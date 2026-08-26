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
    # Programme casework and mobilisation money are readable by default and
    # REVOKED per role below. CanCanCan lets the last matching rule win, so
    # granting here and taking it away in a role's rules is the order that works.
    #
    # The two revocations are deliberately symmetrical, and together they are the
    # political firewall: a REGISTRAR cannot see who sought welfare support, and a
    # PROGRAMME MANAGER cannot see who contributed money. Neither can form the
    # link "this family gave / did not give, so treat their support claim
    # accordingly". Keeping those two views apart is the control.
    can :read, [ ProgrammeCase, CaseDocument ]
    can :read, [ MobilisationCampaign, Contribution, Receipt ]

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
  #
  # A registrar CANNOT see programme cases. "Government support, disability,
  # finance and household data are not visible to everyone" — a case reveals that
  # a family sought welfare support, which is exactly the kind of thing that must
  # not circulate around a village. The registrar's job is capture, verification
  # and resident support; programme casework is not theirs.
  def registrar_rules
    can [ :create, :update ], Household, status: %w[draft pending]
    can :submit_for_verification, Household, status: "draft"
    cannot :verify, Household

    can [ :create, :update ], Person
    can [ :create, :update ], ConsentRecord
    can :withdraw, ConsentRecord

    cannot :read, [ ProgrammeCase, CaseDocument ]

    # Collects pledges and captures receipts in the field, but confirms nothing:
    # whoever takes the money must not be the one who says it arrived.
    can [ :create, :update ], Contribution
    can [ :create, :update ], Receipt
    cannot :verify_receipt, Receipt
    cannot :reconcile, Contribution
    cannot [ :create, :update ], MobilisationCampaign
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

    # Programme casework. An administrator verifies evidence and records what the
    # programme office decided — the platform records outcomes, it does not make
    # them.
    can [ :create, :update ], ProgrammeCase
    can :submit, ProgrammeCase
    can :record_outcome, ProgrammeCase
    can [ :create, :update ], CaseDocument
    can :verify_evidence, CaseDocument

    # Runs mobilisation: approves where money is to go, opens and closes
    # campaigns, verifies receipts and reconciles contributions.
    can [ :create, :update ], MobilisationCampaign
    can [ :approve_account, :open_campaign, :close_campaign ], MobilisationCampaign
    can [ :create, :update ], Contribution
    can :reconcile, Contribution
    can [ :create, :update ], Receipt
    can :verify_receipt, Receipt
  end

  # Owns programme casework. Read-only on the registry itself: a programme
  # manager needs to see households to run cases, not to edit them.
  #
  # Cannot see contributions at all — the other half of the political firewall.
  # Whether a family gave to the roofing fund must not be visible to the person
  # deciding whether their BEAM case goes forward.
  def programme_manager_rules
    cannot [ :create, :update ], [ Household, Person, ConsentRecord ]
    cannot :verify, Household

    can [ :create, :update ], ProgrammeCase
    can :submit, ProgrammeCase
    can :record_outcome, ProgrammeCase
    can [ :create, :update ], CaseDocument
    can :verify_evidence, CaseDocument

    cannot :read, [ MobilisationCampaign, Contribution, Receipt ]
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

    # Can administer cases, but deliberately cannot submit one or decide an
    # outcome: system administration is not programme authority.
    can [ :create, :update ], ProgrammeCase
    can [ :create, :update ], CaseDocument
    cannot [ :submit, :record_outcome ], ProgrammeCase

    # Same principle on the money side: can administer the records, cannot
    # confirm that money arrived or sign off where it goes.
    can [ :create, :update ], [ MobilisationCampaign, Contribution, Receipt ]
    cannot [ :approve_account, :open_campaign ], MobilisationCampaign
    cannot :verify_receipt, Receipt
    cannot :reconcile, Contribution
  end
end
