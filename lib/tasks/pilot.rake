require "csv"

namespace :pilot do
  desc "Print the pilot summary and data-quality report"
  task report: :environment do
    report = PilotReport.new

    puts "\nNyika pilot report — #{Time.current.strftime('%d %b %Y %H:%M')}"
    puts "=" * 60

    puts "\nSummary"
    report.summary_rows.each { |label, value| puts "  #{label.to_s.ljust(38)} #{value}" }

    rate = report.update_rate
    puts "\nResident self-service (deck: 'update rate')"
    puts "  by residents #{rate[:resident]} | by staff #{rate[:assisted]} | resident share #{rate[:percentage]}%"

    puts "\nConsent by purpose"
    report.consent_by_purpose.each do |row|
      puts "  #{row[:purpose].humanize.ljust(20)} active #{row[:active].to_s.rjust(3)}   withdrawn #{row[:withdrawn].to_s.rjust(3)}"
    end

    puts "\nExceptions"
    report.households_missing_fields.each do |household, missing|
      puts "  #{household.reference}  missing: #{missing.join(', ')}"
    end
    report.households_without_members.each do |household|
      puts "  #{household.reference}  no members recorded"
    end
    report.people_without_consent.each do |person|
      puts "  #{person.household.reference}  #{person.name}: no consent recorded"
    end
    report.duplicate_household_groups.each do |group|
      puts "  possible duplicates: #{group.map(&:reference).join(' / ')} (#{group.first.name})"
    end

    if report.households_missing_fields.empty? &&
       report.households_without_members.empty? &&
       report.people_without_consent.empty? &&
       report.duplicate_household_groups.empty?
      puts "  none"
    end

    puts
  end

  desc "Write the pilot summary to CSV (PILOT_CSV=path, default tmp/pilot_summary.csv)"
  task export: :environment do
    path = ENV.fetch("PILOT_CSV", Rails.root.join("tmp", "pilot_summary.csv").to_s)
    report = PilotReport.new

    CSV.open(path, "w") do |csv|
      csv << [ "Measure", "Value" ]
      report.summary_rows.each { |row| csv << row }

      csv << []
      csv << [ "Consent by purpose", "Active", "Withdrawn" ]
      report.consent_by_purpose.each do |row|
        csv << [ row[:purpose].humanize, row[:active], row[:withdrawn] ]
      end

      csv << []
      csv << [ "Exception", "Household", "Detail" ]
      report.households_missing_fields.each do |household, missing|
        csv << [ "Missing required fields", household.reference, missing.join(" ") ]
      end
      report.households_without_members.each do |household|
        csv << [ "No members recorded", household.reference, "" ]
      end
      report.people_without_consent.each do |person|
        csv << [ "No consent recorded", person.household.reference, person.name ]
      end
      report.duplicate_household_groups.each do |group|
        csv << [ "Possible duplicate", group.map(&:reference).join(" "), group.first.name ]
      end
    end

    puts "Wrote #{path}"
  end
end
