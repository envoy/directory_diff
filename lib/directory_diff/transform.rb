module DirectoryDiff
  class Transform
    attr_reader :current_directory

    def initialize(current_directory)
      @current_directory = current_directory
    end

    def into(new_directory)
    end
  end
end
