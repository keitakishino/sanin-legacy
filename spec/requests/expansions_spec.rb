require "rails_helper"

RSpec.describe "Expansions", type: :request do
  before do
    host! "www.example.com"
  end

  describe "GET /expansions" do
    context "when user is not authenticated" do
      it "redirects to signin_path" do
        get "/expansions", params: { q: "mh" }
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is authenticated" do
      let(:user) { create(:user, email: "test@example.com", password: "password123") }

      before do
        post signin_path, params: { email: user.email, password: "password123" }
      end

      it "returns 200 OK" do
        get "/expansions", params: { q: "mh" }
        expect(response).to have_http_status(:ok)
      end

      it "contains turbo-frame with id expansion_suggestions" do
        get "/expansions", params: { q: "mh" }
        expect(response.body).to include('id="expansion_suggestions"')
        expect(response.body).to include('<turbo-frame')
      end

      it "returns response without layout" do
        get "/expansions", params: { q: "mh" }
        expect(response.body).not_to include("<html")
        expect(response.body).not_to include("</html>")
      end

      context "with matching expansions" do
        before do
          create(:expansion, scryfall_set_code: "MH2", name: "Modern Horizons 2", name_ja: "モダンホライゾン2")
          create(:expansion, scryfall_set_code: "MH1", name: "Modern Horizons", name_ja: "モダンホライゾン")
          create(:expansion, scryfall_set_code: "SOI", name: "Shadows over Innistrad", name_ja: nil)
        end

        it "returns matching expansions with prefix match" do
          get "/expansions", params: { q: "mh" }
          expect(response.body).to include("MH2")
          expect(response.body).to include("MH1")
          expect(response.body).not_to include("SOI")
        end

        it "displays scryfall_set_code in uppercase" do
          get "/expansions", params: { q: "mh" }
          expect(response.body).to include("<span class=\"font-bold text-stone-800\">MH2</span>")
          expect(response.body).to include("<span class=\"font-bold text-stone-800\">MH1</span>")
        end

        it "displays name" do
          get "/expansions", params: { q: "mh" }
          expect(response.body).to include("Modern Horizons 2")
          expect(response.body).to include("Modern Horizons")
        end

        it "displays name_ja when present" do
          get "/expansions", params: { q: "mh" }
          expect(response.body).to include("モダンホライゾン2")
          expect(response.body).to include("モダンホライゾン")
        end

        it "does not display name_ja when nil" do
          get "/expansions", params: { q: "SOI" }
          response_body = response.body
          # Verify SOI is present but name_ja is not displayed
          expect(response_body).to include("SOI")
          expect(response_body).to include("Shadows over Innistrad")
          # Check that the name_ja field doesn't appear for SOI
          lines = response_body.split("\n")
          soi_section = lines.find { |line| line.include?("SOI") }
          # The section should not have a third span with Japanese name
          expect(soi_section).not_to include("モダン")
        end

        it "includes data-expansion-code attribute" do
          get "/expansions", params: { q: "mh" }
          expect(response.body).to include('data-expansion-code="MH2"')
          expect(response.body).to include('data-expansion-code="MH1"')
        end
      end

      context "with case-insensitive search" do
        before do
          create(:expansion, scryfall_set_code: "MH2", name: "Modern Horizons 2", name_ja: nil)
          create(:expansion, scryfall_set_code: "SOI", name: "Shadows over Innistrad", name_ja: nil)
        end

        it "finds matches regardless of query case" do
          get "/expansions", params: { q: "MH" }
          expect(response.body).to include("MH2")
          expect(response.body).not_to include("SOI")

          get "/expansions", params: { q: "mh" }
          expect(response.body).to include("MH2")
          expect(response.body).not_to include("SOI")

          get "/expansions", params: { q: "Mh" }
          expect(response.body).to include("MH2")
          expect(response.body).not_to include("SOI")
        end
      end

      context "with empty query" do
        before do
          create(:expansion, scryfall_set_code: "MH2", name: "Modern Horizons 2", name_ja: nil)
        end

        it "returns empty turbo-frame when q is empty string" do
          get "/expansions", params: { q: "" }
          expect(response.body).to include('id="expansion_suggestions"')
          expect(response.body).not_to include("MH2")
        end

        it "returns empty turbo-frame when q parameter is omitted" do
          get "/expansions"
          expect(response.body).to include('id="expansion_suggestions"')
          expect(response.body).not_to include("MH2")
        end
      end

      context "with no matching results" do
        before do
          create(:expansion, scryfall_set_code: "MH2", name: "Modern Horizons 2", name_ja: nil)
        end

        it "returns empty turbo-frame" do
          get "/expansions", params: { q: "xyz" }
          expect(response.body).to include('id="expansion_suggestions"')
          expect(response.body).not_to include("MH2")
        end
      end

      context "with limit of 8 results" do
        before do
          10.times do |i|
            create(:expansion, scryfall_set_code: "M#{i.to_s.rjust(2, '0')}", name: "Magic #{i}", name_ja: nil)
          end
        end

        it "limits results to 8 items" do
          get "/expansions", params: { q: "M" }
          # Count occurrences of data-expansion-code attributes
          count = response.body.scan(/data-expansion-code/).count
          expect(count).to eq(8)
        end
      end

      context "with SQL LIKE wildcard characters" do
        before do
          create(:expansion, scryfall_set_code: "MH2", name: "Modern Horizons 2", name_ja: nil)
          create(:expansion, scryfall_set_code: "MA2", name: "Magic Alliance 2", name_ja: nil)
          create(:expansion, scryfall_set_code: "MX2", name: "Magic X 2", name_ja: nil)
          create(:expansion, scryfall_set_code: "M_2", name: "Magic Underscore 2", name_ja: nil)
          create(:expansion, scryfall_set_code: "MH%", name: "Magic Hash Percent", name_ja: nil)
        end

        it "escapes underscore wildcard in query" do
          # When searching for "M_2", the underscore should be treated as a literal character
          # not as a SQL wildcard (which matches any single character)
          get "/expansions", params: { q: "M_2" }
          # Should match only "M_2" (literal underscore in the code)
          expect(response.body).to include("M_2")
          # Should NOT match "MH2", "MA2", or "MX2" (where underscore would match any char)
          expect(response.body).not_to include("MH2")
          expect(response.body).not_to include("MA2")
          expect(response.body).not_to include("MX2")
        end

        it "escapes percent wildcard in query" do
          # When searching for "MH%", the percent should be treated as a literal character
          # not as a SQL wildcard (which matches zero or more characters)
          get "/expansions", params: { q: "MH%" }
          # Should match only "MH%" (literal percent in the code)
          expect(response.body).to include("MH%")
          # Should NOT match "MH2" (where % would match the "2" or anything after)
          expect(response.body).not_to include("MH2")
        end

        it "handles queries without special characters normally" do
          # Ensure normal prefix matching still works
          get "/expansions", params: { q: "MH" }
          expect(response.body).to include("MH2")
          expect(response.body).to include("MH%")
          expect(response.body).not_to include("MA2")
          expect(response.body).not_to include("MX2")
          expect(response.body).not_to include("M_2")
        end
      end
    end
  end
end
