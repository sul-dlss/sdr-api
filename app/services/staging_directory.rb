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
    ensure_directory_exists!
    FileUtils.cp source, File.join(content_dir, dest)
  end

  attr_reader :content_dir

  private

  def ensure_directory_exists!
    FileUtils.mkdir_p content_dir
  end
end
