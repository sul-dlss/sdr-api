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

  # NOTE: This is a bit of a FactoryBot anti-pattern: creating effectively a
  #       singleton factory, one that is not intended to generate more than one
  #       instance. But we're using it to avoid a bunch of duplicative manual
  #       setup that used to cause flappy specs.
  factory :singleton_blob_with_file, class: 'ActiveStorage::Blob' do
    # Prevent multiple instances
    to_create do |instance|
      attributes = instance.class.find_or_create_by(instance.attributes.compact).attributes
      instance.attributes = attributes.except('id')
      instance.id = attributes['id'] # id can't be mass-assigned
      instance.instance_variable_set('@new_record', false) # marks record as persisted
    end

    key { 'tozuehlw6e8du20vn1xfzmiifyok' }
    filename { 'file2.txt' }
    content_type { 'application/text' }
    byte_size { 10 }
    checksum { 'f5nXiniiM+u/gexbNkOA/A==' }

    # Put the blob's "file" in the expected place
    after(:create) do |blob|
      path_to_blob_file = ActiveStorage::Blob.services.fetch('test').path_for(blob.key)
      FileUtils.mkdir_p(File.dirname(path_to_blob_file))
      File.write(path_to_blob_file, 'HELLO')
    end
  end
end
