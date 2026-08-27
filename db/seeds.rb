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
  # A SECOND administrator, deliberately. Several rules in the registry need one
  # person to do a thing and a different person to confirm it — evidence cannot
  # be verified by whoever recorded it, and a receipt cannot be verified by
  # whoever captured it. With a single administrator those checks deadlock.
  { email: "admin2@nyika.local",     name: "Chipo Chirwa",     role: :administrator },
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
    name: "Moyo homestead", contact: "Sekuru Moyo, 0771 234 567",
    location: "Third homestead past the borehole, along the footpath",
    source: :assisted_visit, status: :verified,
    people: [
      { name: "Tapiwa Moyo",  rel: :head,   band: :age_60_plus, res: :resident,
        consents: %i[village_admin communication programme partner_contact] },
      { name: "Rudo Moyo",    rel: :spouse, band: :age_36_59,   res: :resident,
        consents: %i[village_admin communication],
        # Agreed to partner contact, then changed their mind. The record of both
        # facts is kept — this is what withdrawal looks like in the data.
        withdrawn: %i[partner_contact] },
      { name: "Tanaka Moyo",  rel: :child,  band: :age_5_17,    res: :resident,
        consents: %i[village_admin] }
    ]
  },
  {
    name: "Ncube homestead", contact: "Mai Ncube, 0712 345 678",
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
    name: "Chikwanha homestead", contact: "Baba Chikwanha, ask at the shop",
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
        purpose: purpose, consent_version: ConsentRecord::CURRENT_VERSION,
        channel: :in_person, granted_on: Date.current - rand(1..60),
        recorded_by: registrar, change_reason: "Demo data",
        audit_source_channel: "seed"
      )
    end

    # Consent that was given and later withdrawn. Both rows survive: the register
    # has to be able to show that consent once existed and was then withdrawn.
    Array(person_spec[:withdrawn]).each do |purpose|
      record = person.consent_records.create!(
        purpose: purpose, consent_version: ConsentRecord::CURRENT_VERSION,
        channel: :in_person, granted_on: Date.current - 45,
        recorded_by: registrar, change_reason: "Demo data",
        audit_source_channel: "seed"
      )
      record.audit_source_channel = "seed"
      record.withdraw!(reason: "Asked not to be contacted by partners",
                       note: "Raised at a village meeting")
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

# ---------------------------------------------------------------------------
# Demo programme cases, one at each stage, so the queues and the case dashboard
# have something to show. Illustrative only.
# ---------------------------------------------------------------------------
if ProgrammeCase.none?
  moyo  = Household.find_by(name: "Moyo homestead")
  ncube = Household.find_by(name: "Ncube homestead")

  # 1. A BEAM case blocked on consent — the most common real situation, and the
  #    one that shows the consent model actually gating something.
  if moyo
    child = moyo.active_people.find { |p| p.age_band == "age_5_17" }
    blocked = ProgrammeCase.create!(
      household: moyo, beneficiary: child, programme_type: :beam,
      opened_by: registrar, change_reason: "Demo data", audit_source_channel: "seed"
    )
    blocked.refresh_stage!(reason: "Stage set from consent and evidence on record")
  end

  # 2. A drought relief case that made it all the way to an outcome.
  if ncube
    ncube.active_people.each do |person|
      person.update!(consent_purposes: (person.consent_purposes + %w[programme]).uniq,
                     change_reason: "Agreed to be considered for support")
    end

    completed = ProgrammeCase.create!(
      household: ncube, programme_type: :drought_relief,
      opened_by: registrar, change_reason: "Demo data", audit_source_channel: "seed"
    )

    completed.required_document_types.each do |type|
      document = completed.case_documents.create!(
        document_type: type, uploaded_by: registrar,
        note: "Sighted at the village office", change_reason: "Demo data",
        audit_source_channel: "seed"
      )
      # Verified by someone other than whoever recorded it — the rule the model
      # enforces, shown working in the demo data.
      document.verify!(by: admin, reason: "Confirmed by the village office") if admin
    end

    completed.household.verify!(by: admin, reason: "Confirmed on site visit") if admin && completed.household.pending?
    completed.reload.refresh_stage!(reason: "Evidence complete")

    if admin && completed.submittable?
      completed.submit!(by: admin)
      completed.record_outcome!(outcome: :benefit_received,
                                note: "Maize allocation collected at the village office")
    end
  end

  puts "Seeded #{ProgrammeCase.count} programme cases, #{CaseDocument.count} evidence records."
end

# ---------------------------------------------------------------------------
# A demo mobilisation campaign with a ledger that includes the awkward cases:
# a clean payment, a part-payment exception, and donated labour. A demo where
# everything reconciles teaches nobody anything.
# ---------------------------------------------------------------------------
if MobilisationCampaign.none? && admin
  campaign = MobilisationCampaign.create!(
    name: "Community Centre Roofing Fund",
    purpose: "Roof sheets, timber and labour for the community centre",
    campaign_type: :building_fund, obligation: :voluntary,
    target_amount: 5000, currency: "USD", suggested_contribution: 10,
    opens_on: Date.current - 30, closes_on: Date.current + 60,
    reporting_owner: admin, change_reason: "Agreed at the village meeting",
    audit_source_channel: "seed"
  )
  campaign.approve_receiving_account!(
    by: admin,
    name: "Nyika Village Development Account",
    detail: "Bank 0123456789 — village development committee",
    reason: "Approved by the village development committee"
  )
  campaign.open!(by: admin, reason: "Opened after the account was approved")

  households = Household.live.order(:reference).to_a

  # 1. A contribution that reconciles cleanly.
  if households[0]
    clean = Contribution.create!(mobilisation_campaign: campaign, household: households[0],
                                 contribution_kind: :money, amount: 25, payment_method: :ecocash,
                                 recorded_by: registrar, change_reason: "Demo data",
                                 audit_source_channel: "seed")
    clean.mark_payment_claimed!(reference: "EC-4471902")
    receipt = clean.receipts.create!(payment_rail: :ecocash, external_reference: "EC-4471902",
                                     amount: 25, captured_by: registrar,
                                     change_reason: "Demo data", audit_source_channel: "seed")
    receipt.verify!(by: admin, reason: "Matched against the account statement")
    clean.reconcile!
  end

  # 2. A part payment: pledged 50, paid 20. This is the exception queue doing
  #    its job, and the finance report has something real to show.
  if households[1]
    short = Contribution.create!(mobilisation_campaign: campaign, household: households[1],
                                 contribution_kind: :money, amount: 50, payment_method: :cash_collector,
                                 recorded_by: registrar, change_reason: "Demo data",
                                 audit_source_channel: "seed")
    part = short.receipts.create!(payment_rail: :cash_collector, external_reference: "CASH-014",
                                  amount: 20, captured_by: registrar,
                                  proof_link: "https://storage.example/slips/cash-014.jpg",
                                  change_reason: "Demo data", audit_source_channel: "seed")
    part.verify!(by: admin, reason: "Slip sighted at the village office")
    short.flag_exception!(note: "Paid 20 of 50 pledged; household asked to pay the balance after harvest")
  end

  # 3. Labour, counted and never priced.
  if households[2]
    Contribution.create!(mobilisation_campaign: campaign, household: households[2],
                         contribution_kind: :labour,
                         item_description: "Two days roofing labour, two people",
                         recorded_by: registrar, change_reason: "Demo data",
                         audit_source_channel: "seed")
  end

  puts "Seeded #{MobilisationCampaign.count} campaign, #{Contribution.count} contributions, " \
       "#{Receipt.count} receipts."
end

# ---------------------------------------------------------------------------
# A couple of registration requests, so the queue is not empty in the demo.
# ---------------------------------------------------------------------------
if RegistrationRequest.none?
  [
    { name: "Tendai Marimo", contact: "0771234567",
      location: "Past the school, second homestead on the left",
      note: "Heard about the register at the village meeting." },
    { name: "Grace Sibanda", contact: nil,
      location: "Near the dip tank, homestead with the green door",
      note: "No phone — please visit." }
  ].each do |spec|
    RegistrationRequest.create!(
      name: spec[:name], contact_method: spec[:contact],
      location_hint: spec[:location], note: spec[:note],
      change_reason: "Demo data", audit_source_channel: "seed"
    )
  end

  puts "Seeded #{RegistrationRequest.count} registration requests."
end

# ---------------------------------------------------------------------------
# Village PINs for the demo households.
#
# In real use a registrar issues these in person and writes them down. Seeds set
# known ones so the demo can be signed into, and prints them for the same reason.
# ---------------------------------------------------------------------------
if registrar
  demo_pins = {
    "Moyo homestead" => "246810",
    "Ncube homestead" => "135791"
  }

  demo_pins.each do |household_name, pin|
    household = Household.find_by(name: household_name)
    next if household.nil? || household.pin_set?

    household.audit_source_channel = "seed"
    household.update!(pin: pin, pin_temporary: false, pin_set_at: Time.current,
                      pin_issued_by: registrar, change_reason: "Demo PIN")
    puts "  #{household.reference} #{household.contact_number} PIN #{pin}"
  end
end

# ---------------------------------------------------------------------------
# A diaspora contribution and a couple of comments, so those pages and queues
# are not empty in the demo.
# ---------------------------------------------------------------------------
campaign = MobilisationCampaign.live.first

if campaign && Contribution.from_diaspora.none?
  Contribution.create!(
    mobilisation_campaign: campaign,
    contribution_kind: :money, amount: 150,
    origin: :diaspora, payment_method: :worldremit,
    contributor_name: "Tsitsi Marimo (London)",
    contributor_contact: "+447700900123",
    change_reason: "Demo data", audit_source_channel: "seed"
  )
  puts "Seeded 1 diaspora contribution."
end

if Feedback.none?
  [
    { name: "Sekuru Moyo", contact: "0771234567", category: :village_services,
      message: "The borehole pump has been broken for two weeks. Several households are walking to the river." },
    { name: nil, contact: nil, category: :the_register,
      message: "Please explain at the next meeting what happens to our details if the platform stops being used." }
  ].each do |spec|
    Feedback.create!(name: spec[:name], contact_method: spec[:contact],
                     category: spec[:category], message: spec[:message],
                     change_reason: "Demo data", audit_source_channel: "seed")
  end

  puts "Seeded #{Feedback.count} comments (one anonymous)."
end
