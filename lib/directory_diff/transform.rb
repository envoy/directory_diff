module DirectoryDiff
  class Transform
    attr_reader :current_directory, :new_directory
    attr_reader :transforms, :transforms_index
    attr_reader :options

    def initialize(current_directory)
      @current_directory = current_directory
      @transforms = []
      @transforms_index = {}
    end

    def into(new_directory, options={})
      raise ArgumentError unless new_directory.respond_to?(:each)
      @new_directory = new_directory
      @options = options || {}

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

      # cycle detection
      if transforms_index.has_key?(email)
        return
      end
      transforms_index[email] = nil

      if new_employee.nil?
        add_transform(:delete, old_employee)
        assistant_owner[3] = nil
      else
        own_email = new_employee[1]
        assistant_emails = new_employee[3].to_s.split(",")
        assistant_emails.delete(own_email)

        if assistant_emails.empty?
          assistant_emails = new_employee[3] = nil
        end

        if assistant_emails
          assistant_emails.each do |assistant_email|
            process_employee(assistant_email, new_employee)
          end
        else
          # assistant_emails may be nil. we only use the
          # csv to *set* assistants. if it was nil, we
          # backfill from current employee so that the
          # new record appears to be the same as the
          # current record
          previous_assistants = old_employee&.fetch(3).to_s.split(",")
          previous_assistants.select! do |previous_assistant|
            find_new_employee(previous_assistant)
          end

          if previous_assistants.empty?
            new_employee[3] = nil
          else
            new_employee[3] = previous_assistants.join(",")
          end
        end

        if old_employee.nil?
          add_transform(:insert, new_employee)
        elsif new_employee == old_employee
          add_transform(:noop, old_employee) unless options[:skip_noop]
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
      emails.map do |email|
        [email, new_employees[email]]
      end
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
