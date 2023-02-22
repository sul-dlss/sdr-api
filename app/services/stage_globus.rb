# frozen_string_literal: true

# Moves files from the ActiveStorage to the staging mount
# @param [Hash] globus_ids a mapping of filenames to their location on disk
# @param [String] druid
# @return [Integer] the number of files staged
class StageGlobus
  def self.stage(globus_ids, druid)
    return 0 if globus_ids.blank?

    dir = StagingDirectory.new(druid: druid, staging_location: Settings.staging_location)
    globus_ids.select { |_key, value| value&.match?(%r{^globus://}) }.each do |filename, globus_path|
      dir.copy_file(globus_path.gsub('globus://', Settings.globus_location), filename)
    end.size
  end
end
