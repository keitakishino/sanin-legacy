require "rails_helper"

# 画面は ApplicationController#set_i18n_locale で常に :ja になる。
# その :ja に日付・時刻の書式が無いと l() が I18n::MissingTranslationData を投げ、
# 本番では 500 になる（config/environments/production.rb の
# config.i18n.fallbacks = true は「default_locale(:ja) に落ちる」という意味なので
# config/application.rb の fallbacks = [:en] を打ち消し、英語書式を拾えない）。
#
# テスト環境では [:en] へのフォールバックが効くため、単に落ちないことを確かめるだけでは
# 英語の書式を拾って素通りしてしまう。そこで「日本語として出力されること」を確かめる。
RSpec.describe "ja ロケールの日付・時刻書式" do
  let(:date) { Date.new(2026, 11, 2) }
  let(:time) { Time.zone.local(2026, 11, 2, 15, 4, 5) }

  describe "date" do
    %i[default long short].each do |format|
      it "format: #{format} が日本語で出力される" do
        formatted = I18n.l(date, format: format, locale: :ja)

        expect(formatted).to include("11")
        expect(formatted).not_to match(/[A-Za-z]/), "英語ロケールにフォールバックしている: #{formatted}"
      end
    end

    it "format: :long に年月日が入る" do
      expect(I18n.l(date, format: :long, locale: :ja)).to match(/2026年11月0?2日/)
    end
  end

  describe "time" do
    %i[default long short].each do |format|
      it "format: #{format} が日本語で出力される" do
        formatted = I18n.l(time, format: format, locale: :ja)

        expect(formatted).to include("11")
        expect(formatted).not_to match(/[A-Za-z]/), "英語ロケールにフォールバックしている: #{formatted}"
      end
    end
  end

  # 代理通販の 3 画面が実際に呼んでいる形。2026-11-02 に staging で 500 になった組み合わせ
  describe "代理通販の画面が使う呼び出し" do
    it "l(date, format: :long) が例外を投げない" do
      expect { I18n.l(date, format: :long, locale: :ja) }.not_to raise_error
    end
  end

  describe "アプリ独自の訳" do
    it "rails-i18n より後に読み込まれ、上書きされない" do
      app_index = I18n.load_path.index { |path| path.end_with?("/config/locales/ja.yml") }
      gem_index = I18n.load_path.index { |path| path.include?("rails-i18n") && path.end_with?("ja.yml") }

      expect(app_index).not_to be_nil
      expect(gem_index).not_to be_nil
      expect(app_index).to be > gem_index
    end
  end
end
