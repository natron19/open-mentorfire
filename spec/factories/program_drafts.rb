FactoryBot.define do
  factory :program_draft do
    association :mentor_offer
    status       { "pending" }
    generated_at { nil }
    gemini_raw   { nil }

    trait :completed do
      status            { "completed" }
      generated_at      { Time.current }
      gemini_raw        { "{}" }
      sessions_count    { 3 }
      session_minutes   { 45 }
      name              { "Closing the month on a Sunday" }
      purpose           { "For a new treasurer: what eleven years of co-op books taught me." }
      outcome_statement { "By the last session, the mentee closes a month on their own." }
      sessions do
        [
          { "number" => 1, "title" => "The shoebox of receipts", "aim" => "See where the money goes in.",
            "agenda" => [ { "item" => "Your questions", "minutes" => 10 }, { "item" => "Sort a month of receipts", "minutes" => 25 },
                          { "item" => "Agree tasks", "minutes" => 5 } ] },
          { "number" => 2, "title" => "The double invoice", "aim" => "Catch a mistake before it costs the rent.",
            "agenda" => [ { "item" => "Look back", "minutes" => 10 }, { "item" => "Reconcile one statement", "minutes" => 25 },
                          { "item" => "Agree tasks", "minutes" => 5 } ] },
          { "number" => 3, "title" => "The first close alone", "aim" => "Close a month alone; the mentorship ends here.",
            "agenda" => [ { "item" => "The mentee walks through the close", "minutes" => 25 }, { "item" => "The one-page report", "minutes" => 10 },
                          { "item" => "What you keep", "minutes" => 5 } ] }
        ]
      end
      tasks do
        [
          { "name" => "Bring last month's receipts", "session_number" => 1, "assignee" => "mentee" },
          { "name" => "Bring my old ledger page", "session_number" => 1, "assignee" => "mentor" },
          { "name" => "Reconcile one bank statement", "session_number" => 2, "assignee" => "mentee" },
          { "name" => "Find the supplier's last three invoices", "session_number" => 2, "assignee" => "mentee" },
          { "name" => "Close the month on your own", "session_number" => 3, "assignee" => "mentee" },
          { "name" => "Keep a page of questions as they come up", "session_number" => 0, "assignee" => "mentee" }
        ]
      end
      first_intro_questions do
        [ "What made you say yes to being treasurer?", "Have you kept accounts for anything before?",
          "What would you like to be able to do by the end?" ]
      end
    end

    trait :failed do
      status         { "failed" }
      generated_at   { Time.current }
      gemini_raw     { "malformed response" }
      failure_reason { "JSON parse failed: unexpected token" }
    end
  end
end
