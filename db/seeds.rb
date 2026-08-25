# Demo data for the Nyika registry POC. Safe to re-run: every record is looked up
# before it is created.
#
# NEVER put real household data in this file. Seeds are committed to the
# repository; resident data is not.

unless Rails.env.development? || Rails.env.test?
  abort "Refusing to seed outside development/test."
end

# Development-only password. Override with SEED_PASSWORD in .env.
password = ENV.fetch("SEED_PASSWORD", "nyika-dev-password")

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
