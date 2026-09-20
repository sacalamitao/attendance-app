FactoryBot.define do
  factory :attendance do
    event { association :event, :open }
    attendee
    operator { association :user }
    scanned_at { Time.current }
    ministry_classification { attendee.ministry_on(event.event_date) || Ministry::YAN }
  end
end
