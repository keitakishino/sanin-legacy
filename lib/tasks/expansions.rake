namespace :expansions do
  desc "Import expansions from Scryfall API"
  task import_from_scryfall: :environment do
    importer = ScryfallExpansionImporter.new
    result = importer.call

    if result[:success]
      puts result[:message]
    else
      warn result[:message]
    end

    exit(1) unless result[:success]
  end
end
