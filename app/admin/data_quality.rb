ActiveAdmin.register_page "Data quality" do
  menu label: "Data quality", priority: 40

  content title: "Data quality and pilot metrics" do
    report = PilotReport.new

    panel "Pilot summary" do
      para "The go/no-go question from the brief: can Nyika keep this record "\
           "accurate, trusted and useful without unsustainable admin labour?"

      table_for report.summary_rows do
        column("Measure") { |row| row.first }
        column("Value")   { |row| row.last }
      end
    end

    if authorized?(:read, ProgrammeCase)
      panel "Programme cases" do
        para "Deck: cases opened, evidence received and outcomes logged."
        table_for report.case_rows do
          column("Measure") { |row| row.first }
          column("Value")   { |row| row.last }
        end
      end

      panel "Case outcomes" do
        para "Recorded, not decided: the programme office keeps its decision authority."
        table_for report.cases_by_outcome do
          column("Outcome") { |row| row[:outcome].humanize }
          column("Cases")   { |row| row[:count] }
        end
      end
    end

    if authorized?(:read, Contribution)
      panel "Payment reconciliation" do
        para "The registry reconciles payments; it never holds funds. These figures "\
             "describe money that moved through a licensed rail or an authorised collector."
        table_for report.payment_rows do
          column("Measure") { |row| row.first }
          column("Value")   { |row| row.last }
        end
      end

      panel "Campaign ledgers" do
        ledgers = report.campaign_ledgers

        if ledgers.any?
          table_for ledgers do
            column("Campaign") { |l| link_to l[:campaign].reference, admin_mobilisation_campaign_path(l[:campaign]) }
            column("Name") { |l| l[:campaign].name }
            column("Target") { |l| l[:target] }
            column("Received") { |l| l[:received] }
            column("Pending") { |l| l[:pending] }
            column("Exceptions") { |l| l[:exceptions] }
            column("Outstanding") { |l| l[:outstanding] }
            column("Progress") { |l| l[:progress] ? "#{l[:progress]}%" : "—" }
            column("Households yet to give") { |l| l[:households_outstanding] }
          end
        else
          para "No campaigns yet."
        end
      end

      panel "Finance exceptions" do
        exceptions = report.payment_exceptions

        if exceptions.any?
          para "Payments that will not match. These are a queue to work, not a "\
               "failure to hide."
          table_for exceptions do
            column("Contribution") { |k| link_to k.reference, admin_contribution_path(k) }
            column("Campaign") { |k| k.mobilisation_campaign.reference }
            column("Household") { |k| k.household.reference }
            column("Expected") { |k| k.describes }
            column("Receipted") { |k| k.receipted_amount }
            column("Note") { |k| k.exception_note }
          end
        else
          para "No payment exceptions outstanding."
        end
      end
    end

    panel "Resident self-service" do
      rate = report.update_rate
      para "The pilot has to report how many residents can update without "\
           "assistance. This is measured from the source channel recorded on "\
           "every audited change."

      table_for [ rate ] do
        column("Updates by residents")   { |r| r[:resident] }
        column("Updates by staff")       { |r| r[:assisted] }
        column("Total updates")          { |r| r[:total] }
        column("Resident share")         { |r| "#{r[:percentage]}%" }
      end
    end

    panel "Possible duplicate households" do
      groups = report.duplicate_household_groups

      if groups.any?
        para "Matched on name and location. Confirm before merging — two families "\
             "can genuinely share a name."
        table_for groups do
          column("Name")      { |group| group.first.name }
          column("Location")  { |group| group.first.location_description }
          column("Records") do |group|
            group.map { |h| link_to h.reference, admin_household_path(h) }
                 .reduce { |a, b| a.to_s + ", " + b.to_s }&.html_safe
          end
        end
      else
        para "No possible duplicates found."
      end
    end

    panel "Households missing required fields" do
      rows = report.households_missing_fields

      if rows.any?
        table_for rows do
          column("Household") { |row| link_to row.first.reference, admin_household_path(row.first) }
          column("Name")      { |row| row.first.name }
          column("Status")    { |row| row.first.status.humanize }
          column("Missing")   { |row| row.last.map(&:humanize).join(", ") }
        end
      else
        para "Every live household has its required fields."
      end
    end

    panel "Households with no members recorded" do
      rows = report.households_without_members

      if rows.any?
        table_for rows do
          column("Household") { |h| link_to h.reference, admin_household_path(h) }
          column("Name")      { |h| h.name }
          column("Status")    { |h| h.status.humanize }
        end
      else
        para "Every live household has at least one member."
      end
    end

    panel "People with no consent recorded" do
      rows = report.people_without_consent

      if rows.any?
        para "A person in the register who has agreed to nothing is an exception "\
             "to resolve, not a default to leave in place."
        table_for rows do
          column("Person")    { |p| link_to p.name, admin_person_path(p) }
          column("Household") { |p| link_to p.household.reference, admin_household_path(p.household) }
        end
      else
        para "Everyone in the register has at least one recorded consent."
      end
    end

    panel "Consent by purpose" do
      para "Reported per purpose because there is no single consent figure: "\
           "agreeing to be contacted is not agreeing to be enrolled or paid."
      table_for report.consent_by_purpose do
        column("Purpose")   { |row| row[:purpose].humanize }
        column("Active")    { |row| row[:active] }
        column("Withdrawn") { |row| row[:withdrawn] }
      end
    end
  end
end
