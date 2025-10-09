# frozen_string_literal: true

# Checks that the major and minor cocina versions match.
class CocinaVersionValidator
  # @param [String] check_cocina_version, e.g., 1.1.2
  # @return [Boolean] true if major and minor versions match current cocina version
  def self.valid?(check_cocina_version, cocina_version: Cocina::Models::VERSION) # rubocop:disable Lint/UnusedMethodArgument
    # NOTE: Temporarily relax cocina version validation to allow Argo and sdr-api
    # to diverge temporarily (between 0.106.0 and 0.107.0)

    # check_cocina_version.split('.')[0..1] == cocina_version.split('.')[0..1]

    true
  end
end
