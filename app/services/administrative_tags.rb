# frozen_string_literal: true

# Return a list of administrative tags for a given type URI
class AdministrativeTags
  def self.for(type:)
    case type
    when Cocina::Models::Vocab.book
      # NOTE: For now, we assume all books are LTR until we learn how to discern
      #       otherwise. See related issue:
      #       https://github.com/sul-dlss/google-books/issues/184
      ['Process : Content Type : Book (ltr)'].freeze
    else
      [].freeze
    end
  end
end
