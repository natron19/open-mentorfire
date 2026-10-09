require "rails_helper"

RSpec.describe "MentorOffers", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  let(:offer) { create(:mentor_offer, user: user) }

  let(:valid_params) do
    { mentor_offer: { subject: "Fixing bikes at the repair café",
                      experience: "I have run the bike bench at the repair café once a month for five years.",
                      who_its_for: "A neighbor who fixes their own bike.", sessions_count: "5", session_minutes: "90" } }
  end

  context "when not signed in" do
    it "redirects every page to sign in" do
      get mentor_offers_path
      expect(response).to redirect_to(sign_in_path)
      get dashboard_path
      expect(response).to redirect_to(sign_in_path)
      post mentor_offers_path, params: valid_params
      expect(response).to redirect_to(sign_in_path)
    end
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "shows the dashboard with only the user's own offers" do
      create(:mentor_offer, user: user, subject: "Mine to draft")
      create(:mentor_offer, user: other, subject: "Someone else's offer")
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("What I could mentor", "Mine to draft")
      expect(response.body).not_to include("Someone else&#39;s offer")
    end

    it "shows the latest Program name on the dashboard" do
      create(:program_draft, :completed, mentor_offer: offer)
      get mentor_offers_path
      expect(response.body).to include("Closing the month on a Sunday")
    end

    it "shows an empty state with no offers" do
      get mentor_offers_path
      expect(response.body).to include("Write your first offer")
    end

    it "renders the new form with the labels the UI journey fills" do
      get new_mentor_offer_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Subject", "What you have actually done", "Who it is for", "Number of sessions", "Session length")
    end

    it "creates an offer and redirects to it" do
      expect { post mentor_offers_path, params: valid_params }.to change(user.mentor_offers, :count).by(1)
      offer = MentorOffer.last
      expect(response).to redirect_to(mentor_offer_path(offer))
      expect([ offer.sessions_count, offer.session_minutes ]).to eq([ 5, 90 ])
    end

    it "re-renders the form with 422 on invalid input" do
      expect {
        post mentor_offers_path, params: { mentor_offer: valid_params[:mentor_offer].merge(experience: "short") }
      }.not_to change(MentorOffer, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "shows the offer with the Draft my Program button" do
      get mentor_offer_path(offer)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(offer.subject, "Draft my Program")
    end

    it "updates an offer" do
      patch mentor_offer_path(offer), params: { mentor_offer: { sessions_count: "6" } }
      expect(response).to redirect_to(mentor_offer_path(offer))
      expect(offer.reload.sessions_count).to eq(6)
    end

    it "rejects an invalid update with 422" do
      patch mentor_offer_path(offer), params: { mentor_offer: { sessions_count: "12" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "deletes an offer" do
      offer
      expect { delete mentor_offer_path(offer) }.to change(MentorOffer, :count).by(-1)
      expect(response).to redirect_to(mentor_offers_path)
    end
  end

  # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
  context "when signed in as a different user" do
    before { sign_in_as(other) }

    it "cannot see, edit, update, or delete the offer" do
      get mentor_offer_path(offer)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
      get edit_mentor_offer_path(offer)
      expect(response).to redirect_to(root_path)
      patch mentor_offer_path(offer), params: { mentor_offer: { subject: "Hijacked" } }
      expect(response).to redirect_to(root_path)
      expect { delete mentor_offer_path(offer) }.not_to change(MentorOffer, :count)
      expect(response).to redirect_to(root_path)
      expect(offer.reload.subject).not_to eq("Hijacked")
    end
  end
end
