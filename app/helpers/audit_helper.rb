module AuditHelper
  # Turns a version's whodunnit into something a person can read.
  #
  # Staff changes store a User id. Resident changes have no signed-in user, so they
  # store "household:<id>" — without this they would render as "system", which
  # would wrongly attribute a household's own correction to the software.
  def audit_actor_label(version)
    who = version.whodunnit

    return "system" if who.blank?

    if who.start_with?("household:")
      household = Household.find_by(id: who.split(":").last)
      household ? "#{household.name} (household)" : "a household"
    else
      User.find_by(id: who)&.display_name || "system"
    end
  end

  # "Assisted visit" reads better than "assisted" in a table.
  def audit_channel_label(version)
    version.source_channel.presence&.humanize || "Unknown"
  end
end
