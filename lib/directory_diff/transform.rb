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

      unseen_employees.each do |email, employee|
        process_employee(email, employee)
      end

      transforms
    end

    protected
    def process_employee(email, assistant_owner)
      new_employee = find_new_employee(email)
      old_employee = find_current_employee(email)

      if new_employee.nil?
        add_transform(:delete, old_employee)
        assistant_owner[3] = nil
      else
        if assistant_email = new_employee[3]
          process_employee(assistant_email, new_employee)
        end

        if old_employee.nil?
          add_transform(:insert, new_employee)
        elsif new_employee == old_employee
          add_transform(:noop, old_employee)
        else
          add_transform(:update, new_employee)
        end
      end
    end

    def add_transform(op, employee)
      return if employee.nil?
      email = employee[1]
      existing_operation = transforms_index[email]
      if existing_operation.nil?
        operation = [op, *employee]
        transforms_index[email] = operation
        transforms << operation
      end
    end

    def find_new_employee(email)
      new_employees[email]
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
      accum = []
      emails.each do |email|
        accum << [email, new_employees[email]]
      end
      accum
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
