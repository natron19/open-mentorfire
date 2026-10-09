require "rails_helper"

RSpec.describe ProgramDraft, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:program_draft)).to be_valid
    end

    it "requires a mentor offer" do
      expect(build(:program_draft, mentor_offer: nil)).not_to be_valid
    end

    it "accepts every known status and rejects others" do
      ProgramDraft::STATUSES.each { |s| expect(build(:program_draft, status: s)).to be_valid }
      expect(build(:program_draft, status: "unknown")).not_to be_valid
    end

    it "lists the statuses and the two assignees" do
      expect(ProgramDraft::STATUSES).to eq(%w[pending completed failed])
      expect(ProgramDraft::ASSIGNEES).to eq(%w[mentor mentee])
    end
  end

  describe "associations" do
    it "has a user through its offer" do
      draft = create(:program_draft)
      expect(draft.user).to eq(draft.mentor_offer.user)
    end
  end

  describe "defaults" do
    it "starts pending with empty lists" do
      draft = ProgramDraft.create!(mentor_offer: create(:mentor_offer))
      expect(draft.status).to eq("pending")
      expect([ draft.sessions, draft.tasks, draft.first_intro_questions ]).to all(eq([]))
    end
  end

  describe "#stale?" do
    it "is true when the offer changed after the draft" do
      draft = create(:program_draft, :completed, generated_at: 1.hour.ago)
      draft.mentor_offer.update!(subject: "Keeping the books, and the board report")
      expect(draft.stale?).to be(true)
    end

    it "is false when the draft is newer than the offer" do
      draft = create(:program_draft, :completed, generated_at: 1.minute.from_now)
      expect(draft.stale?).to be(false)
    end
  end

  describe "task placement" do
    let(:draft) { build(:program_draft, :completed) }

    it "groups tasks by session and keeps session 0 at program level" do
      expect(draft.tasks_for(1).map { |t| t["name"] }).to eq([ "Bring last month's receipts", "Bring my old ledger page" ])
      expect(draft.program_level_tasks.map { |t| t["name"] }).to eq([ "Keep a page of questions as they come up" ])
    end

    it "adds up a session's agenda minutes" do
      expect(draft.agenda_minutes(draft.sessions.first)).to eq(40)
    end
  end

  describe "#to_markdown" do
    it "includes the purpose, every session with its agenda and tasks, the intro questions, and the offer" do
      draft = create(:program_draft, :completed)
      md = draft.to_markdown
      expect(md).to include("# Closing the month on a Sunday", "**Shape:** 3 sessions of 45 minutes")
      expect(md).to include("> #{draft.outcome_statement}")
      expect(md).to include("### Session 2: The double invoice", "- 25 min: Reconcile one statement")
      expect(md).to include("Agenda total: 40 of 45 minutes.")
      expect(md).to include("- [ ] Bring my old ledger page (mentor)")
      expect(md).to include("## Any time during the Program", "- [ ] Keep a page of questions as they come up (mentee)")
      expect(md).to include("1. What made you say yes to being treasurer?")
      expect(md).to include(draft.mentor_offer.experience)
    end

    it "names the file after the Program" do
      draft = create(:program_draft, :completed)
      expect(draft.markdown_filename).to eq("closing-the-month-on-a-sunday-program.md")
    end
  end
end
