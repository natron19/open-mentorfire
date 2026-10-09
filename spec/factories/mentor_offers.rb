FactoryBot.define do
  factory :mentor_offer do
    association :user
    subject         { "Keeping the books for a small food co-op" }
    experience      { "I kept the books for a food co-op for eleven years and learned to close every month on the same Sunday." }
    who_its_for     { "A member who has just volunteered to be treasurer." }
    sessions_count  { 3 }
    session_minutes { 45 }
  end
end
