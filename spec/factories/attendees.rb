FactoryBot.define do
  factory :attendee do
    sequence(:full_name) { |n| "Attendee #{n.to_s.rjust(4, '0')}" }
    gender { Gender::MALE }
    # 25 years old today → YAN
    birthdate { Date.current.prev_year(25) }

    trait :female do
      gender { Gender::FEMALE }
    end

    trait :kkb do
      birthdate { Date.current.prev_year(16) }
    end

    trait :yan do
      birthdate { Date.current.prev_year(25) }
    end

    trait :mens do
      gender { Gender::MALE }
      birthdate { Date.current.prev_year(40) }
    end

    trait :womens do
      gender { Gender::FEMALE }
      birthdate { Date.current.prev_year(40) }
    end

    trait :inactive do
      deactivated_at { 1.day.ago }
    end
  end
end
