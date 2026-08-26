# Demo data for the Nyika registry POC. Safe to re-run: every record is looked up
# before it is created.
#
# NEVER put real household data in this file. Seeds are committed to the
# repository; resident data is not.

# Demo accounts exist in the hosted POC too, so seeding is allowed in production —
# but only with an explicitly supplied password. The fallback below is committed to
# a public repository, so it must never be what protects a deployed instance.
password =
  if Rails.env.development? || Rails.env.test?
    ENV.fetch("SEED_PASSWORD", "nyika-dev-password")
  else
    ENV["SEED_PASSWORD"].presence ||
      abort("Refusing to seed #{Rails.env}: set SEED_PASSWORD to a private value first.")
  end

demo_users = [
  { email: "registrar@nyika.local",  name: "Rudo Registrar",   role: :registrar },
  { email: "admin@nyika.local",      name: "Anesu Admin",      role: :administrator },
  { email: "programme@nyika.local",  name: "Panashe Poulton",  role: :programme_manager },
  { email: "tech@nyika.local",       name: "Tendai Tech",      role: :tech_admin }
]

demo_users.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.name = attrs[:name]
  user.role = attrs[:role]
  # Always set the password, not just on create. These are demo accounts, so
  # rotating SEED_PASSWORD and redeploying should actually change how you sign in.
  user.password = password
  user.save!
  puts "  #{user.role.ljust(18)} #{user.email}"
end

puts "Seeded #{User.count} users."

# ---------------------------------------------------------------------------
# Demo households. Illustrative only — every name and place here is invented.
# NEVER put real household data in this file: seeds are committed to a public
# repository, resident data is not.
# ---------------------------------------------------------------------------
registrar = User.find_by(email: "registrar@nyika.local")
admin     = User.find_by(email: "admin@nyika.local")
PaperTrail.request.whodunnit = registrar&.id.to_s

DEMO_HOUSEHOLDS = [
  {
    name: "Moyo homestead", contact: "Sekuru Moyo",
    location: "Third homestead past the borehole, along the footpath",
    source: :assisted_visit, status: :verified,
    people: [
      { name: "Tapiwa Moyo",  rel: :head,   band: :age_60_plus, res: :resident,
        consents: %i[village_admin communication programme] },
      { name: "Rudo Moyo",    rel: :spouse, band: :age_36_59,   res: :resident,
        consents: %i[village_admin communication] },
      { name: "Tanaka Moyo",  rel: :child,  band: :age_5_17,    res: :resident,
        consents: %i[village_admin] }
    ]
  },
  {
    name: "Ncube homestead", contact: "Mai Ncube",
    location: "Next to the primary school, blue gate",
    source: :community_event, status: :pending,
    people: [
      { name: "Sibongile Ncube", rel: :head,  band: :age_36_59, res: :resident,
        consents: %i[village_admin communication payment] },
      { name: "Thabo Ncube",     rel: :child, band: :under_5,   res: :resident,
        consents: %i[village_admin] }
    ]
  },
  {
    name: "Chikwanha homestead", contact: "Baba Chikwanha",
    location: "Beyond the dip tank, last homestead before the river",
    source: :assisted_visit, status: :draft,
    people: [
      { name: "Farai Chikwanha", rel: :head, band: :age_18_35, res: :resident,
        consents: %i[village_admin] }
    ]
  },
  {
    # Deliberately incomplete, so the exceptions panel and the data-quality
    # report (plan step 7) have something to report.
    name: "Dube homestead", contact: nil, location: nil,
    source: :self_reported, status: :draft, people: []
  }
]

DEMO_HOUSEHOLDS.each do |spec|
  household = Household.find_or_initialize_by(name: spec[:name])
  next if household.persisted?

  household.assign_attributes(
    principal_contact: spec[:contact],
    location_description: spec[:location],
    capture_source: spec[:source],
    captured_by: registrar,
    change_reason: "Demo data"
  )
  household.save!

  spec[:people].each do |person_spec|
    person = household.people.create!(
      name: person_spec[:name], relationship: person_spec[:rel],
      age_band: person_spec[:band], residency_status: person_spec[:res],
      change_reason: "Demo data"
    )

    person_spec[:consents].each do |purpose|
      person.consent_records.create!(
        purpose: purpose, consent_version: "v1", channel: :in_person,
        granted_on: Date.current - rand(1..60), recorded_by: registrar,
        change_reason: "Demo data"
      )
    end
  end

  # Walk the lifecycle so the queues and the audit trail both have content.
  if %i[pending verified].include?(spec[:status])
    household.submit_for_verification!(reason: "Capture complete")
  end
  if spec[:status] == :verified && admin
    PaperTrail.request.whodunnit = admin.id.to_s
    household.verify!(by: admin, reason: "Confirmed on site visit")
    PaperTrail.request.whodunnit = registrar&.id.to_s
  end
end

puts "Seeded #{Household.count} households, #{Person.count} people, " \
     "#{ConsentRecord.count} consent records."
