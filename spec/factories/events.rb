FactoryBot.define do
  factory :event do
    sequence(:name) { |n| "Sunday Service #{n}" }
    event_date { Date.current }
    start_time { "09:00" }
    end_time { "11:00" }
    location { "Main Sanctuary" }
    status { "draft" }

    trait :open do
      status { "open" }
      opened_at { 1.hour.ago }
    end

    trait :closed do
      status { "closed" }
      opened_at { 3.hours.ago }
      closed_at { 1.hour.ago }
    end
  end
end
