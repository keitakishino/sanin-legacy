namespace :card_names do
  desc "Import card names from Scryfall API"
  task import_from_scryfall: :environment do
    result = ScryfallCardNameImporter.new.call

    if result[:success]
      puts result[:message]
    else
      warn result[:message]
      exit(1)
    end
  end
end
