RSpec.describe "shared/_event_type_label", type: :view do
  describe "rendering event type labels" do
    it "renders trade type with correct color" do
      render partial: "shared/event_type_label", locals: { event_type: "trade" }

      fragment = Nokogiri::HTML.fragment(rendered)
      span = fragment.at_css("span")

      expect(span).to have_text("トレード")
      classes = span[:class].split
      expect(classes).to include("bg-want-soft")
      expect(classes).to include("text-want-text")
    end

    it "renders tournament type with correct color" do
      render partial: "shared/event_type_label", locals: { event_type: "tournament" }

      fragment = Nokogiri::HTML.fragment(rendered)
      span = fragment.at_css("span")

      expect(span).to have_text("大会")
      classes = span[:class].split
      expect(classes).to include("bg-warning-soft")
      expect(classes).to include("text-warning")
    end

    it "renders proxy_order type with correct color" do
      render partial: "shared/event_type_label", locals: { event_type: "proxy_order" }

      fragment = Nokogiri::HTML.fragment(rendered)
      span = fragment.at_css("span")

      expect(span).to have_text("代理通販")
      classes = span[:class].split
      expect(classes).to include("bg-accent-soft")
      expect(classes).to include("text-accent")
    end

    it "renders unknown type with neutral color" do
      render partial: "shared/event_type_label", locals: { event_type: "unknown_type" }

      fragment = Nokogiri::HTML.fragment(rendered)
      span = fragment.at_css("span")

      classes = span[:class].split
      expect(classes).to include("bg-neutral-soft")
      expect(classes).to include("text-stone-500")
      expect(classes).not_to include("bg-want-soft")
      expect(classes).not_to include("bg-warning-soft")
      expect(classes).not_to include("bg-accent-soft")
    end

    it "renders symbol type correctly" do
      render partial: "shared/event_type_label", locals: { event_type: :trade }

      fragment = Nokogiri::HTML.fragment(rendered)
      span = fragment.at_css("span")

      expect(span).to have_text("トレード")
      classes = span[:class].split
      expect(classes).to include("bg-want-soft")
      expect(classes).to include("text-want-text")
    end
  end
end
