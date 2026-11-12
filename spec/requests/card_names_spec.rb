require "rails_helper"

RSpec.describe "CardNames API" do
  describe "GET /card_names" do
    let(:user) { create(:user) }

    before do
      host! "www.example.com"
      post signin_path, params: {
        email: user.email,
        password: user.password
      }
    end

    it "未ログインは signin_path にリダイレクト" do
      delete signout_path
      get "/card_names", params: { q: "light" }
      expect(response).to redirect_to(signin_path)
    end

    it "ログイン時は 200、レイアウト無し" do
      create(:card_name, name: "Lightning Bolt")

      get "/card_names", params: { q: "light" }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('<html')
      expect(response.body).not_to include('</html>')
    end

    it "< turbo-frame id=\"card_name_suggestions\">" do
      create(:card_name, name: "Lightning Bolt")

      get "/card_names", params: { q: "light" }

      expect(response.body).to include('turbo-frame id="card_name_suggestions"')
    end

    it "frame=foo を渡すと id=\"foo\"" do
      create(:card_name, name: "Lightning Bolt")

      get "/card_names", params: { q: "light", frame: "my_frame" }

      expect(response.body).to include('turbo-frame id="my_frame"')
    end

    it "[C1] q を渡すと card_names の一致する名前が data-expansion-code 付きで返る" do
      create(:card_name, name: "Lightning Bolt")
      create(:card_name, name: "Black Lotus")

      get "/card_names", params: { q: "light" }

      expect(response.body).to include('data-expansion-code="Lightning Bolt"')
      expect(response.body).not_to include('data-expansion-code="Black Lotus"')
    end

    it "並び順: 前方一致を先、単語先頭一致、部分一致の順" do
      create(:card_name, name: "Bolt Bend")
      create(:card_name, name: "Lightning Bolt")
      create(:card_name, name: "Thunderbolt")

      get "/card_names", params: { q: "bolt" }

      body = response.body
      bolt_bend_pos = body.index('data-expansion-code="Bolt Bend"')
      lightning_pos = body.index('data-expansion-code="Lightning Bolt"')
      thunder_pos = body.index('data-expansion-code="Thunderbolt"')

      expect(bolt_bend_pos).to be < lightning_pos
      expect(lightning_pos).to be < thunder_pos
    end

    it "q が空で候補 0 件" do
      create(:card_name, name: "Lightning Bolt")

      get "/card_names", params: { q: "" }

      expect(response.body).not_to include('data-expansion-code=')
    end

    it "q が省略で候補 0 件" do
      create(:card_name, name: "Lightning Bolt")

      get "/card_names"

      expect(response.body).not_to include('data-expansion-code=')
    end

    it "上限 8 件" do
      9.times { |i| create(:card_name, name: "Test Card #{i}") }

      get "/card_names", params: { q: "test" }

      expect(response.body.scan(/data-expansion-code=/).count).to eq(8)
    end

    it "大文字小文字を区別しない" do
      create(:card_name, name: "Lightning Bolt")

      get "/card_names", params: { q: "LIGHT" }

      expect(response.body).to include('data-expansion-code="Lightning Bolt"')
    end
  end
end
