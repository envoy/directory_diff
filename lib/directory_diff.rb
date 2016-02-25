require "directory_diff/version"
require "directory_diff/transform"

module DirectoryDiff
  def self.transform(current_directory)
    raise ArgumentError unless current_directory.respond_to?(:each)
    Transform.new(current_directory)
  end
end
