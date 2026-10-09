require "rails_helper"

RSpec.describe MentorOffer, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:mentor_offer)).to be_valid
    end

    it "requires a user" do
      expect(build(:mentor_offer, user: nil)).not_to be_valid
    end

    it "requires a subject of 3 to 120 characters" do
      expect(build(:mentor_offer, subject: "")).not_to be_valid
      expect(build(:mentor_offer, subject: "ab")).not_to be_valid
      expect(build(:mentor_offer, subject: "x" * 121)).not_to be_valid
    end

    it "requires experience of 40 to 2500 characters" do
      expect(build(:mentor_offer, experience: "Too short to draft from")).not_to be_valid
      expect(build(:mentor_offer, experience: "x" * 2501)).not_to be_valid
      expect(build(:mentor_offer, experience: "x" * 2500)).to be_valid
    end

    it "requires who_its_for of 10 to 600 characters" do
      expect(build(:mentor_offer, who_its_for: "")).not_to be_valid
      expect(build(:mentor_offer, who_its_for: "anyone")).not_to be_valid
      expect(build(:mentor_offer, who_its_for: "x" * 601)).not_to be_valid
    end

    it "accepts 3 to 8 sessions and nothing else" do
      MentorOffer::SESSION_COUNTS.each { |n| expect(build(:mentor_offer, sessions_count: n)).to be_valid }
      [ nil, 2, 9 ].each { |n| expect(build(:mentor_offer, sessions_count: n)).not_to be_valid }
    end

    it "accepts the listed session lengths and nothing else" do
      MentorOffer::SESSION_LENGTHS.each { |m| expect(build(:mentor_offer, session_minutes: m)).to be_valid }
      [ nil, 20, 120 ].each { |m| expect(build(:mentor_offer, session_minutes: m)).not_to be_valid }
    end
  end

  describe "constants" do
    it "lists the session counts and lengths" do
      expect(MentorOffer::SESSION_COUNTS).to eq([ 3, 4, 5, 6, 7, 8 ])
      expect(MentorOffer::SESSION_LENGTHS).to eq([ 30, 45, 60, 90 ])
    end
  end

  describe "associations" do
    it "destroys its program drafts" do
      offer = create(:mentor_offer)
      create(:program_draft, :completed, mentor_offer: offer)
      expect { offer.destroy }.to change(ProgramDraft, :count).by(-1)
    end

    it "returns the newest draft as latest_program_draft" do
      offer = create(:mentor_offer)
      create(:program_draft, :completed, mentor_offer: offer, generated_at: 2.days.ago)
      newest = create(:program_draft, :completed, mentor_offer: offer, generated_at: 1.hour.ago)
      expect(offer.reload.latest_program_draft).to eq(newest)
    end

    it "is destroyed with its user" do
      offer = create(:mentor_offer)
      expect { offer.user.destroy }.to change(MentorOffer, :count).by(-1)
    end
  end

  describe "#ai_variables" do
    it "sends the offer fields as strings, and nothing about the mentor's account" do
      offer = build(:mentor_offer, sessions_count: 5, session_minutes: 90)
      vars = offer.ai_variables
      expect(vars.keys).to eq(%i[subject experience who_its_for sessions_count session_minutes])
      expect(vars.values_at(:sessions_count, :session_minutes)).to eq(%w[5 90])
      expect(vars.values.join).not_to include(offer.user.name, offer.user.email)
    end
  end

  it "describes its shape" do
    expect(build(:mentor_offer, sessions_count: 4, session_minutes: 60).shape_label).to eq("4 sessions of 60 minutes")
  end
end
