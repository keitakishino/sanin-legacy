require "rails_helper"

RSpec.describe "pages/home", type: :view do
  context "when user is not signed in" do
    before do
      without_partial_double_verification { allow(view).to receive(:user_signed_in?).and_return(false) }
      render
    end

    it "includes Google button" do
      expect(rendered).to include("/auth/google")
    end

    it "does not show X button on home page" do
      expect(rendered).not_to include("/auth/twitter")
      expect(rendered).not_to include("X (Twitter)")
      expect(rendered).not_to include("Sign In with X (Twitter)")
    end

    it "does not show twitter account link" do
      expect(rendered).not_to include("twitter.com")
    end
  end
end
