require "rails_helper"

RSpec.describe "Home", type: :request do
  it "shows the pitch and the fictional example to visitors" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("A first season behind the stall", "What each loaf really costs", "https://mentorfire.com")
    expect(response.body).to include("Try it free")
  end

  it "sends a signed-in member to their offers" do
    sign_in_as(create(:user))
    get root_path
    expect(response.body).to include("Go to my offers")
  end
end
