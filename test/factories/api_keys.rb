FactoryGirl.define do
  factory :api_key do
    account_id 1
    description 'An API Key for account #1'
    name { Faker::Lorem.characters(5) }
    key { Faker::Internet.slug }
    terms '1'
  end
end