require "rails_helper"

RSpec.describe "admin.users の訳" do
  describe "日本語の翻訳キー" do
    it "既存の画面の文言と紐づけ用の文言の両方が引ける" do
      expect(I18n.t("admin.users.title", locale: :ja)).to eq("ユーザー管理")
      expect(I18n.t("admin.users.nav_label", locale: :ja)).to eq("ユーザー管理")
      expect(I18n.t("admin.users.registered_info", locale: :ja)).to eq("登録情報")
      expect(I18n.exists?("admin.users.guest_link.conflict", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.conflict_discarded", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.not_found", :ja)).to be true
    end
  end

  describe "英語の翻訳キー" do
    it "紐づけ用の文言キーが引ける" do
      expect(I18n.exists?("admin.users.guest_link.conflict", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.conflict_discarded", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.not_found", :en)).to be true
    end
  end

  describe "YAML のキーの重複" do
    def find_duplicate_keys(node, path = [])
      duplicates = []

      return duplicates unless node.is_a?(Psych::Nodes::Mapping)

      seen_keys = {}

      node.children.each_slice(2) do |key_node, value_node|
        key = key_node.is_a?(Psych::Nodes::Scalar) ? key_node.value : key_node.to_s
        current_path = path + [ key ]

        if seen_keys[key]
          duplicates << current_path.join(".")
        end
        seen_keys[key] = true

        if value_node.is_a?(Psych::Nodes::Mapping)
          duplicates += find_duplicate_keys(value_node, current_path)
        elsif value_node.is_a?(Psych::Nodes::Sequence)
          value_node.children.each do |child|
            duplicates += find_duplicate_keys(child, current_path) if child.is_a?(Psych::Nodes::Mapping)
          end
        end
      end

      duplicates
    end

    it "ja.yml に重なったキーがない" do
      ja_ast = Psych.parse_file(Rails.root.join("config/locales/ja.yml"))
      # Psych.parse_file returns a Psych::Nodes::Document
      document_node = ja_ast.children.first
      duplicates = find_duplicate_keys(document_node)
      expect(duplicates).to be_empty, "Duplicate keys found: #{duplicates.join(', ')}"
    end

    it "en.yml に重なったキーがない" do
      en_ast = Psych.parse_file(Rails.root.join("config/locales/en.yml"))
      # Psych.parse_file returns a Psych::Nodes::Document
      document_node = en_ast.children.first
      duplicates = find_duplicate_keys(document_node)
      expect(duplicates).to be_empty, "Duplicate keys found: #{duplicates.join(', ')}"
    end
  end
end
