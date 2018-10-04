require_relative "transformer/in_memory"

module DirectoryDiff
  class Transform
    attr_reader :current_directory

    def initialize(current_directory)
      @current_directory = current_directory
    end

    def into(new_directory, options = {})
      Transformer::InMemory.new(current_directory).into(new_directory, options)
    end
  end
end
