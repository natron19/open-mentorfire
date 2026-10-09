require "rails_helper"

RSpec.describe "ProgramDrafts", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  # 3 sessions of 45 minutes
  let(:offer) { create(:mentor_offer, user: user) }

  # A valid mentorfire_program_v1 answer for the offer above, built from the factory's completed draft.
  let(:valid_result) do
    attrs = attributes_for(:program_draft, :completed)
    {
      "name"                  => attrs[:name],
      "purpose"               => attrs[:purpose],
      "outcome_statement"     => attrs[:outcome_statement],
      "sessions"              => attrs[:sessions],
      "tasks"                 => attrs[:tasks],
      "first_intro_questions" => attrs[:first_intro_questions]
    }
  end

  def with_session(index, changes)
    sessions = valid_result["sessions"].deep_dup
    sessions[index] = sessions[index].merge(changes)
    valid_result.merge("sessions" => sessions)
  end

  def with_task(index, changes)
    tasks = valid_result["tasks"].deep_dup
    tasks[index] = tasks[index].merge(changes)
    valid_result.merge("tasks" => tasks)
  end

  def draft_program
    post mentor_offer_program_drafts_path(offer)
  end

  describe "POST /offers/:mentor_offer_id/drafts" do
    context "when not signed in" do
      it "redirects to sign in" do
        draft_program
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in as the owner with a valid response" do
      before do
        sign_in_as(user)
        gemini_returns(valid_result.to_json)
      end

      it "calls GeminiService with the template and the offer's variables" do
        expect(GeminiService).to receive(:generate).with(
          template:  "mentorfire_program_v1",
          variables: {
            subject:         offer.subject,
            experience:      offer.experience,
            who_its_for:     offer.who_its_for,
            sessions_count:  "3",
            session_minutes: "45"
          }
        ).and_return(valid_result.to_json)
        draft_program
      end

      it "creates a completed draft with the parsed fields, the raw response, and the offer's shape" do
        expect { draft_program }.to change(ProgramDraft, :count).by(1)
        draft = ProgramDraft.last
        expect(draft.status).to eq("completed")
        expect(draft.gemini_raw).to eq(valid_result.to_json)
        expect(draft.name).to eq(valid_result["name"])
        expect(draft.sessions.size).to eq(3)
        expect(draft.tasks.map { |t| t["assignee"] }.uniq).to contain_exactly("mentor", "mentee")
        expect(draft.first_intro_questions.size).to eq(3)
        expect([ draft.sessions_count, draft.session_minutes ]).to eq([ 3, 45 ])
        expect(draft.generated_at).to be_present
      end

      it "redirects to the result page" do
        draft_program
        expect(response).to redirect_to(mentor_offer_program_draft_path(offer, ProgramDraft.last))
      end

      it "accepts a response wrapped in a ```json fence" do
        gemini_returns("```json\n#{valid_result.to_json}\n```")
        draft_program
        expect(ProgramDraft.last.status).to eq("completed")
      end

      it "accepts whole-number floats and a capitalized assignee, and stores them normalized" do
        gemini_returns(with_task(0, "assignee" => " Mentee ", "session_number" => 1.0).to_json)
        draft_program
        draft = ProgramDraft.last
        expect(draft.status).to eq("completed")
        expect(draft.tasks.first).to include("assignee" => "mentee", "session_number" => 1)
      end
    end

    context "when the response cannot be used" do
      before { sign_in_as(user) }

      {
        "is not JSON"                             => -> { "this is not json at all" },
        "is a JSON array"                         => -> { "[1, 2]" },
        "has no name"                             => -> { valid_result.except("name").to_json },
        "has a blank outcome_statement"           => -> { valid_result.merge("outcome_statement" => " ").to_json },
        "has a session without an aim"            => -> { with_session(1, "aim" => "").to_json },
        "has a session with two agenda items"     => -> { with_session(0, "agenda" => valid_result["sessions"][0]["agenda"].first(2)).to_json },
        "has an agenda item with zero minutes"    => -> { with_session(0, "agenda" => [ { "item" => "A", "minutes" => 0 } ] * 3).to_json },
        "has minutes written as a string"         => -> { with_session(0, "agenda" => [ { "item" => "A", "minutes" => "10" } ] * 3).to_json },
        "has five tasks"                          => -> { valid_result.merge("tasks" => valid_result["tasks"].first(5)).to_json },
        "has a task without a session_number"     => -> { with_task(0, "session_number" => nil).to_json },
        "has two intro questions"                 => -> { valid_result.merge("first_intro_questions" => valid_result["first_intro_questions"].first(2)).to_json }
      }.each do |description, build_text|
        it "marks the draft failed and keeps the raw text when the response #{description}" do
          text = instance_exec(&build_text)
          gemini_returns(text)

          expect { draft_program }.to change(ProgramDraft, :count).by(1)
          draft = ProgramDraft.last
          expect(draft.status).to eq("failed")
          expect(draft.gemini_raw).to eq(text)
          expect(draft.failure_reason).to be_present
          expect(response).to redirect_to(mentor_offer_program_draft_path(offer, draft))
        end
      end

      # The three code-enforced hard rules (ProgramRulesCheck), each mirrored in evals/cases/mentorfire_program_v1.yml.
      it "fails a draft with more sessions than the offer asked for" do
        extra = { "number" => 4, "title" => "One more", "aim" => "Keep going.",
                  "agenda" => [ { "item" => "A", "minutes" => 10 } ] * 3 }
        gemini_returns(valid_result.merge("sessions" => valid_result["sessions"] + [ extra ]).to_json)

        draft_program
        draft = ProgramDraft.last
        expect(draft.status).to eq("failed")
        expect(draft.failure_reason).to eq("The draft had 4 sessions, not the 3 you asked for")
      end

      it "fails a draft whose agenda runs over the session length" do
        long = [ { "item" => "A", "minutes" => 20 }, { "item" => "B", "minutes" => 20 }, { "item" => "C", "minutes" => 10 } ]
        gemini_returns(with_session(1, "agenda" => long).to_json)

        draft_program
        expect(ProgramDraft.last.failure_reason).to eq("Session 2's agenda adds up to 50 minutes, more than the 45-minute session")
      end

      it "fails a draft that gives a task to either of them, and the page explains why" do
        gemini_returns(with_task(2, "assignee" => "either").to_json)

        draft_program
        draft = ProgramDraft.last
        expect(draft.status).to eq("failed")
        expect(draft.failure_reason).to eq("Task 3 is given to \"either\", not the mentor or the mentee")

        follow_redirect!
        expect(response.body).to include("could not be used", "not the mentor or the mentee", "Retry", "&quot;either&quot;")
        expect(response.body).not_to include("Download .md")
      end

      it "fails a draft with a task placed on a session that does not exist" do
        gemini_returns(with_task(0, "session_number" => 7).to_json)
        draft_program
        expect(ProgramDraft.last.failure_reason).to eq("Task 1 is placed on session 7, which does not exist")
      end
    end

    context "when GeminiService raises" do
      before { sign_in_as(user) }

      {
        GeminiService::BudgetExceededError => "daily AI request limit",
        GeminiService::GatekeeperError     => "couldn't be processed",
        GeminiService::OutputGuardError    => "didn't pass our safety checks",
        GeminiService::TimeoutError        => "took too long",
        GeminiService::GeminiError         => "An unexpected error occurred"
      }.each do |error_class, message|
        it "renders the #{error_class.name.demodulize} message with 422 and creates no draft" do
          gemini_raises(error_class)
          expect { draft_program }.not_to change(ProgramDraft, :count)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include(message)
        end
      end
    end

    # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
    context "when signed in as a different user" do
      it "does not find the offer, calls no AI, and creates no draft" do
        sign_in_as(other)
        expect(GeminiService).not_to receive(:generate)
        expect { draft_program }.not_to change(ProgramDraft, :count)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("That record could not be found.")
      end
    end

    context "rate limit" do
      it "refuses the 11th draft within a minute" do
        sign_in_as(user)
        gemini_returns(valid_result.to_json)
        10.times { draft_program }
        expect(response).to have_http_status(:redirect)
        draft_program
        expect(response).to have_http_status(:too_many_requests)
        expect(ProgramDraft.count).to eq(10)
      end
    end
  end

  describe "GET /offers/:mentor_offer_id/drafts (the error page's Try again)" do
    it "redirects to the offer" do
      sign_in_as(user)
      get mentor_offer_program_drafts_path(offer)
      expect(response).to redirect_to(mentor_offer_path(offer))
    end
  end

  describe "GET /offers/:mentor_offer_id/drafts/:id" do
    context "for a completed draft" do
      let(:draft) { create(:program_draft, :completed, mentor_offer: offer, generated_at: 1.minute.from_now) }

      it "shows the Program, every session with its agenda and tasks, the intro questions, actions, and disclaimer" do
        sign_in_as(user)
        get mentor_offer_program_draft_path(offer, draft)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(
          draft.name, draft.purpose, draft.outcome_statement, "3 sessions of 45 minutes",
          "Session 1: The shoebox of receipts", "Sort a month of receipts", "40 of 45 min",
          "Bring my old ledger page", "Any time during the Program", "Keep a page of questions as they come up",
          "Three questions for the first intro", draft.first_intro_questions.last,
          "Download .md", "Show raw response", "AI-generated."
        )
        expect(response.body).not_to include("Your offer has changed")
      end
    end

    context "for a failed draft" do
      it "shows the reason, Retry, and the raw response, with no download" do
        draft = create(:program_draft, :failed, mentor_offer: offer)
        sign_in_as(user)
        get mentor_offer_program_draft_path(offer, draft)
        expect(response.body).to include("could not be used", draft.failure_reason, "Retry", "malformed response")
        expect(response.body).not_to include("Download .md")
      end
    end

    it "warns when the offer changed after the draft" do
      draft = create(:program_draft, :completed, mentor_offer: offer, generated_at: 1.hour.ago)
      offer.update!(subject: "Keeping the books, and the board report")
      sign_in_as(user)
      get mentor_offer_program_draft_path(offer, draft)
      expect(response.body).to include("Your offer has changed since this draft")
    end

    it "does not show another user's draft" do
      draft = create(:program_draft, :completed, mentor_offer: offer)
      sign_in_as(other)
      get mentor_offer_program_draft_path(offer, draft)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
    end

    it "does not show a draft under a different offer of the same user" do
      draft = create(:program_draft, :completed, mentor_offer: offer)
      sign_in_as(user)
      get mentor_offer_program_draft_path(create(:mentor_offer, user: user), draft)
      expect(response).to redirect_to(root_path)
    end
  end
end
