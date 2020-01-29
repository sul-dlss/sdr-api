# frozen_string_literal: true

FactoryBot.define do
  factory :active_storage_blob, class: 'ActiveStorage::Blob' do
    sequence(:key) do |n|
      "abc123-#{n}"
    end

    byte_size { 123 }
    checksum { 'abcdefghijklmnopqrstuvwxyz' }
    created_at { Time.current }
    filename { 'file.txt' }
  end
end
