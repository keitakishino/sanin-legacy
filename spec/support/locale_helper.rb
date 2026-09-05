module LocaleHelper
  def with_locale(locale)
    original_locale = I18n.locale
    begin
      I18n.locale = locale
      yield
    ensure
      I18n.locale = original_locale
    end
  end
end

RSpec.configure do |config|
  config.include LocaleHelper, type: :model
  config.include LocaleHelper, type: :request
end
