require "net/http"
require "json"

# Service for importing Magic: The Gathering expansions from Scryfall API
# Handles fetching set data, filtering, and persisting to database
class ScryfallExpansionImporter
  class ScryfallApiError < StandardError; end
  class ProcessingError < StandardError; end

  SCRYFALL_SETS_URL = "https://api.scryfall.com/sets"
  API_TIMEOUT_SECONDS = 30
  SKIPPED_SET_TYPES = %w[promo token].freeze

  def call
    Rails.logger.info("Starting Scryfall expansion import")
    created_count = 0
    skipped_count = 0
    error_count = 0

    sets_data = fetch_sets_from_scryfall

    sets_data.each do |set_data|
      if should_skip_set?(set_data)
        Rails.logger.info("Skipping set #{set_data['code']} (set_type: #{set_data['set_type']})")
        skipped_count += 1
        next
      end

      result = process_set(set_data)
      case result
      when :created
        created_count += 1
      when :skipped
        skipped_count += 1
      when :error
        error_count += 1
      end
    end

    message = "Expansion import completed: #{created_count} created, #{skipped_count} skipped, #{error_count} errors"
    Rails.logger.info(message)

    {
      success: error_count == 0,
      message: message,
      created_count: created_count,
      skipped_count: skipped_count,
      error_count: error_count
    }
  rescue ScryfallApiError => e
    error_msg = "Scryfall API error: #{e.message}"
    Rails.logger.error(error_msg)
    { success: false, message: error_msg, created_count: 0, skipped_count: 0, error_count: 0 }
  end

  private

  def fetch_sets_from_scryfall
    Rails.logger.info("Fetching sets from Scryfall API: #{SCRYFALL_SETS_URL}")

    uri = URI(SCRYFALL_SETS_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = API_TIMEOUT_SECONDS
    http.open_timeout = API_TIMEOUT_SECONDS

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    case response.code.to_i
    when 200
      data = JSON.parse(response.body)

      # Validate response structure: 'data' key must exist and be an array
      unless data.is_a?(Hash) && data["data"].is_a?(Array)
        error_msg = "Invalid Scryfall API response structure: 'data' key missing or not an array. Response: #{data.inspect}"
        Rails.logger.error(error_msg)
        raise ScryfallApiError, error_msg
      end

      Rails.logger.info("Successfully fetched #{data['data'].length} sets from Scryfall")
      data["data"]
    else
      raise ScryfallApiError, "API returned status #{response.code}: #{response.body}"
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise ScryfallApiError, "API request timeout: #{e.message}"
  rescue JSON::ParserError => e
    raise ScryfallApiError, "Failed to parse Scryfall API response: #{e.message}"
  rescue StandardError => e
    raise ScryfallApiError, "Unexpected error fetching from Scryfall: #{e.message}"
  end

  def should_skip_set?(set_data)
    SKIPPED_SET_TYPES.include?(set_data["set_type"])
  end

  def process_set(set_data)
    # Validate that code exists and is not empty
    code = set_data["code"]
    if code.nil? || code.to_s.strip.empty?
      error_msg = "Set code is nil or empty for set data: #{set_data.inspect}"
      Rails.logger.error(error_msg)
      return :error
    end

    code = code.upcase
    name = set_data["name"]
    name_ja = set_data["printed_name"]

    existing = Expansion.find_by(scryfall_set_code: code)
    if existing.present?
      Rails.logger.info("Expansion #{code} already exists, skipping")
      return :skipped
    end

    expansion = Expansion.create(
      scryfall_set_code: code,
      name: name,
      name_ja: name_ja
    )

    if expansion.persisted?
      Rails.logger.info("Created expansion: #{code} - #{name}")
      :created
    else
      # Handle validation errors
      if expansion.errors.of_kind?(:scryfall_set_code, :taken)
        # Uniqueness constraint violation (race condition) - treat as skipped
        Rails.logger.info("Expansion #{code} already exists (race condition), skipping")
        :skipped
      else
        # Other validation errors
        error_msg = "Failed to create expansion #{code}: #{expansion.errors.full_messages.join(', ')}"
        Rails.logger.error(error_msg)
        :error
      end
    end
  rescue StandardError => e
    error_msg = "Unexpected error processing set #{set_data['code']}: #{e.message}"
    Rails.logger.error(error_msg)
    :error
  end
end
