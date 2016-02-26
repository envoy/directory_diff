module DirectoryDiff
  class Transform
    attr_reader :current_directory, :new_directory
    attr_reader :transforms, :transforms_index

    def initialize(current_directory)
      @current_directory = current_directory
      @transforms = []
      @transforms_index = {}
    end

    def into(new_directory)
      raise ArgumentError unless new_directory.respond_to?(:each)
      @new_directory = new_directory

      current_employees.each do |email, employee|
        process_employee(email, employee)
      end

      unseen_employees.each do |employee|
        add_transform(:insert, employee)
      end

      transforms
    end

    protected
    def process_employee(email, employee)
      new_employee = find_new_employee(email)

      if new_employee.nil?
        add_transform(:delete, employee)
      elsif new_employee == employee
        add_transform(:noop, employee)
      else
        add_transform(:update, new_employee)
      end
    end

    def add_transform(op, employee)
      emit_transform(op, employee) do |operation|
        transforms << operation
      end
    end

    def prepend_transform(op, employee)
      emit_transform(op, employee) do |operation|
        transforms.unshift(operation)
      end
    end

    def emit_transform(op, employee)
      email = employee[1]
      existing_operation = transforms_index[email]
      if existing_operation.nil?
        operation = [op, *employee]
        transforms_index[email] = operation
        yield operation
      end
    end

    def find_new_employee(email)
      transforms_index[email] || new_employees[email]
    end

    def find_current_employee(email)
      current_employees[email]
    end

    def new_employees
      @new_employees ||= build_index(new_directory)
    end

    def current_employees
      @current_employees ||= build_index(current_directory)
    end

    def unseen_employees
      emails = new_employees.keys - current_employees.keys
      new_employees.values_at(*emails)
    end

    def build_index(directory)
      accum = {}
      directory.each do |employee|
        email = employee[1]
        accum[email] = employee
      end
      accum
    end
  end
end
