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
  user.password = password if user.new_record?
  user.save!
  puts "  #{user.role.ljust(18)} #{user.email}"
end

puts "Seeded #{User.count} users."
