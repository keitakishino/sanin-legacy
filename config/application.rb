require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SaninLegacy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Host Authorization configuration
    config.hosts << "www.example.com"

    # Set default locale to Japanese
    config.i18n.default_locale = :ja

    # Fall back to English for any key not translated in ja.yml (e.g. Rails'
    # built-in ActiveRecord/ActiveModel validation messages such as
    # "can't be blank" or "has already been taken", which are not defined by
    # this app and would otherwise render as "Translation missing").
    config.i18n.fallbacks = [ :en ]

    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
