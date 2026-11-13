require "json"

class ScryfallCardNameImporter
  class ScryfallApiError < StandardError; end

  SCRYFALL_CARD_NAMES_URL = "https://api.scryfall.com/catalog/card-names".freeze
  BATCH_SIZE = 1000

  def call
    Rails.logger.info("Starting card name import from Scryfall")
    created_count = 0
    skipped_count = 0

    response = ScryfallHttp.get(SCRYFALL_CARD_NAMES_URL)

    case response.code.to_i
    when 200
      data = JSON.parse(response.body)

      unless data.is_a?(Hash) && data["data"].is_a?(Array)
        error_msg = "Invalid Scryfall API response structure: 'data' key missing or not an array"
        Rails.logger.error(error_msg)
        raise ScryfallApiError, error_msg
      end

      names = data["data"]
        .map { _1.to_s.strip }
        .reject(&:blank?)
        .uniq

      Rails.logger.info("Fetched #{names.length} card names from Scryfall")

      names.each_slice(BATCH_SIZE) do |slice|
        rows = CardName.insert_all(
          slice.map { { name: _1 } },
          unique_by: :name,
          returning: [ :id ]
        )
        created_count += rows.count
      end

      skipped_count = names.length - created_count
      message = "Card name import completed: #{created_count} created, #{skipped_count} skipped"
      Rails.logger.info(message)

      {
        success: true,
        message: message,
        created_count: created_count,
        skipped_count: skipped_count
      }
    else
      raise ScryfallApiError, "API returned status #{response.code}: #{response.body}"
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    handle_error("API request timeout: #{e.message}")
  rescue JSON::ParserError => e
    handle_error("Failed to parse Scryfall API response: #{e.message}")
  rescue ScryfallApiError => e
    handle_error("Scryfall API error: #{e.message}")
  rescue StandardError => e
    handle_error("Unexpected error: #{e.message}")
  end

  private

  def handle_error(message)
    Rails.logger.error(message)
    {
      success: false,
      message: message,
      created_count: 0,
      skipped_count: 0
    }
  end
end
