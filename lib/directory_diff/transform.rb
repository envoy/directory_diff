require_relative "transformer/in_memory"
require_relative "transformer/temp_table"

module DirectoryDiff
  class Transform
    attr_reader :current_directory

    def initialize(current_directory)
      @current_directory = current_directory
    end

    def into(new_directory, options = {})
      processor_class = processor_for(options[:processor])
      processor_class.new(current_directory).into(new_directory, options)
    end

    private

    def processor_for(processor)
      case processor
      when nil, :in_memory
        Transformer::InMemory
      when :temp_table
        Transformer::TempTable
      else
        raise ArgumentError, "unsupported processor #{processor.inspect}"
      end
    end
  end
end
