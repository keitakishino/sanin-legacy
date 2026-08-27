FactoryBot.define do
  factory :expansion do
    scryfall_set_code { Faker::Alphanumeric.unique.alphanumeric(number: 3).upcase }
    name { Faker::Lorem.word }
    name_ja { Faker::Lorem.word }
  end
end
