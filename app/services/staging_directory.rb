# frozen_string_literal: true

# This represents the staging directory where we place files so the assembly
# robot can access them
class StagingDirectory
  def initialize(druid:, staging_location:)
    @druid = druid
    @druid_tree_folder = DruidTools::Druid.new(druid, staging_location).path
    @content_dir = File.join(@druid_tree_folder, 'content')
  end

  def copy_file(source, dest)
    dest_filepath = File.join(content_dir, dest)
    FileUtils.mkdir_p File.dirname(dest_filepath)
    FileUtils.cp source, dest_filepath
  end

  attr_reader :content_dir
end
