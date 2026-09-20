# Idempotent seeds.
#
# Always: ensure an administrator exists. Credentials come from ADMIN_EMAIL /
# ADMIN_PASSWORD; in development they default to admin@example.com / password123!
#
# Development only: sample attendees and events so the UI has data to show.

admin_email = ENV.fetch("ADMIN_EMAIL") { Rails.env.production? ? nil : "admin@example.com" }
admin_password = ENV.fetch("ADMIN_PASSWORD") { Rails.env.production? ? nil : "password123!" }

if admin_email.present? && admin_password.present?
  admin = User.find_or_initialize_by(email: admin_email)
  if admin.new_record?
    admin.assign_attributes(name: ENV.fetch("ADMIN_NAME", "Administrator"), role: "admin", password: admin_password)
    admin.save!
    puts "Created admin user #{admin_email}"
  else
    puts "Admin user #{admin_email} already exists"
  end
elsif Rails.env.production?
  puts "Skipping admin creation: set ADMIN_EMAIL and ADMIN_PASSWORD to seed an administrator."
end

if Rails.env.development?
  operator = User.find_or_create_by!(email: "operator@example.com") do |u|
    u.name = "Scanner Operator"
    u.role = "operator"
    u.password = "password123!"
  end

  samples = [
    [ "Maria Santos",   "female", 16 ], [ "Juan Dela Cruz", "male",   19 ], [ "Ana Reyes",     "female", 21 ],
    [ "Pedro Garcia",   "male",   22 ], [ "Liza Bautista", "female", 25 ], [ "Carlo Mendoza", "male",   28 ],
    [ "Ramon Villanueva", "male", 29 ], [ "Jose Aquino",   "male",   45 ], [ "Ben Torres",    "male",   61 ],
    [ "Grace Lim",      "female", 29 ], [ "Rosa Fernandez", "female", 38 ], [ "Elena Cruz",   "female", 70 ]
  ]
  samples.each do |name, gender, age|
    Attendee.find_or_create_by!(full_name: name) do |a|
      a.gender = gender
      a.birthdate = Date.current.prev_year(age) - rand(0..300)
    end
  end

  Event.find_or_create_by!(name: "Sunday Worship Service", event_date: Date.current) do |e|
    e.start_time = "09:00"
    e.end_time = "11:00"
    e.location = "Main Sanctuary"
  end
  Event.find_or_create_by!(name: "Midweek Prayer Meeting", event_date: Date.current + 3) do |e|
    e.start_time = "19:00"
    e.end_time = "20:30"
    e.location = "Fellowship Hall"
  end

  closed = Event.find_or_create_by!(name: "Youth Fellowship", event_date: Date.current - 7) do |e|
    e.start_time = "15:00"
    e.end_time = "17:00"
    e.location = "Youth Room"
    e.status = "closed"
    e.opened_at = (Date.current - 7).in_time_zone.change(hour: 14, min: 45)
    e.closed_at = (Date.current - 7).in_time_zone.change(hour: 17, min: 15)
  end
  if closed.attendances.none?
    Attendee.active.limit(7).each_with_index do |attendee, i|
      classification = attendee.ministry_on(closed.event_date) or next
      Attendance.create!(event: closed, attendee: attendee, operator: operator,
                         scanned_at: closed.opened_at + (i * 4).minutes, ministry_classification: classification)
    end
  end

  puts "Seeded #{Attendee.count} attendees, #{Event.count} events, #{Attendance.count} attendances"
  puts "Sign in: admin@example.com / password123!  (operator: operator@example.com / password123!)"
end
