# frozen_string_literal: true

FactoryBot.define do
  sequence :email do |n|
    "person#{n}@example.com"
  end

  factory :user do
    email { generate(:email) }
    password { 'password' }
    collections { [] }
    full_access { true }
    active { true }
  end
end
