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
      expect(I18n.exists?("admin.users.guest_link.unlink_success", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_not_found", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_conflict_name", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_conflict_name_discarded", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_conflict_username", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.section_title", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.open_button", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.search_label", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.search_button", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.too_many", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.submit", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.success", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.more_orders", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.not_selectable", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.linked_title", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.linked_empty", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.column_action", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_button", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_modal_title", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_confirm", :ja)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_submit", :ja)).to be true
    end
  end

  describe "英語の翻訳キー" do
    it "紐づけ用の文言キーが引ける" do
      expect(I18n.exists?("admin.users.guest_link.conflict", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.conflict_discarded", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.not_found", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_success", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_not_found", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_conflict_name", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_conflict_name_discarded", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_conflict_username", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.section_title", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.open_button", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.search_label", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.search_button", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.too_many", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.submit", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.success", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.more_orders", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.not_selectable", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.linked_title", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.linked_empty", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.column_action", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_button", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_modal_title", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_confirm", :en)).to be true
      expect(I18n.exists?("admin.users.guest_link.unlink_submit", :en)).to be true
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
