require "envoy/activerecord_pg_stuff"

Arel::Predications.module_eval do
  def contains(other)
    Arel::Nodes::InfixOperation.new(:"@>", self, other)
  end
end

module DirectoryDiff
  module Transformer
    class TempTable
      attr_reader :current_directory, :operations

      # @params current_directory a relation that filters out only the records
      #                           that represent the current directory. This is
      #                           mostly likely an Employee relation. This
      #                           relation will be pulled into a temporary table.
      def initialize(current_directory)
        @current_directory = current_directory
        @operations = []
      end

      # @param new_directory a table containing only the new records to compare
      #                      against, most likely a temp table.
      def into(new_directory, options = {})
        projection = <<-SQL
          name, 
          lower(email) email, 
          coalesce(phone_number, '') phone_number,
          array_remove(
            regexp_split_to_array(
              coalesce(assistants, ''),
              '\s*,\s*'
            )::varchar[],
            ''
          ) assistants
        SQL
        current_directory.select(projection).temporary_table do |temp_current_directory|
          # Remove dupe email rows, keeping the last one
          latest_unique_sql = <<-SQL
            SELECT 
              DISTINCT ON (lower(email)) name, 
              lower(email) email,
              coalesce(phone_number, '') phone_number,
              array_remove(
                regexp_split_to_array(
                  coalesce(assistants, ''),
                  '\s*,\s*'
                )::varchar[],
                ''
              ) assistants, 
              extra, 
              ROW_NUMBER () OVER ()
            FROM 
              #{new_directory.arel_table.name} 
            ORDER BY 
              lower(email), 
              row_number desc
          SQL

          new_directory.select('*')
            .from(Arel.sql("(#{latest_unique_sql}) as t"))
            .order("row_number").temporary_table do |deduped_csv|
            # Get Arel tables for referencing fields, table names
            employees = temp_current_directory.table
            csv = deduped_csv.table

            # Reusable Arel predicates
            csv_employee_join = csv[:email].eq(employees[:email])
            attributes_unchanged = employees[:name].eq(csv[:name])
                                    .and(employees[:phone_number].eq(csv[:phone_number]))
                                    .and(employees[:assistants].contains(csv[:assistants]))

            # Creates joins between the temp table and the csv table and
            # vice versa
            # Cribbed from https://gist.github.com/mildmojo/3724189
            csv_to_employees = csv.join(employees, Arel::Nodes::OuterJoin)
                                .on(csv_employee_join)
                                .join_sources
            employees_to_csv = employees.join(csv, Arel::Nodes::OuterJoin)
                                .on(csv_employee_join)
                                .join_sources

            # Representation of the joined csv-employees, with csv on the left
            csv_records = deduped_csv.joins(csv_to_employees).order('row_number asc')
            # Representation of the joined employees-csv, with employees on the
            # left
            employee_records = temp_current_directory.joins(employees_to_csv)

            # Cleanup some bad records
            # 1. Assistant email is set on an employee, but no assistant record
            #    in csv. Remove the assistant email.
            # 2. Assistant email is employee's own email. Remove the assistant
            #    email.
            # TODO move this into the temp table creation above
            # https://www.db-fiddle.com/f/gxg6qABP1LygYvvgRvyH2N/1
            cleanup_sql = <<-SQL
              with
                unnested_assistants as
                (
                  select
                    email,
                    name,
                    unnest(assistants) assistant
                  from #{csv.name} 
                ),
                own_email_removed as
                (
                  select
                    a.*
                  from unnested_assistants a
                  where a.email != a.assistant
                ),
                missing_assistants_removed as
                (
                  select
                    a.*
                  from own_email_removed a
                  left outer join #{csv.name} b on a.assistant = b.email
                  where
                    (a.assistant is null and b.email is null)
                    or (a.assistant is not null and b.email is not null)
                ),
                only_valid_assistants as
                (
                  select
                    a.email, 
                    a.name,
                    array_remove(
                      array_agg(b.assistant),
                      null
                    ) assistants
                  from #{csv.name} a
                  left outer join missing_assistants_removed b
                  using (email)
                  group by
                    a.email, a.name
                )
              update #{csv.name}
              set assistants = only_valid_assistants.assistants
              from only_valid_assistants
              where #{csv.name}.email = only_valid_assistants.email
            SQL
            deduped_csv.connection.execute(cleanup_sql)

            # new records are records in the new directory that don't exist in
            # the current directory
            new_records = csv_records.select("'insert'::varchar operation, row_number")
                            .select(:name, :email, :phone_number, :assistants, :extra)
                            .where({ employees.name => { email: nil } })
            # deleted records are records in the current directory that don't
            # exist in the new directory
            deleted_records = employee_records.select("'delete'::varchar operation, row_number")
                                .select(:name, :email, :phone_number, :assistants, :extra)
                                .where({ csv.name => { email: nil } })
            # changed records are records that have difference in name, phone
            # number and/or assistants
            changed_records = csv_records.select("'update'::varchar operation, row_number")
                                .select(:name, :email, :phone_number, :assistants, :extra)
                                .where.not(attributes_unchanged)
            # unchanged records are records that are exactly the same in both
            # directories (without considering the extra field)
            unchanged_records = csv_records.select("'noop'::varchar operation, row_number")
                                  .select(:name, :email, :phone_number, :assistants, :extra)
                                  .where(attributes_unchanged)

            # create temp table for holding operations
            operations_temp_table = "temporary_operations_#{self.object_id}"
            deduped_csv.connection.with_temporary_table operations_temp_table, new_records.to_sql do |name|
              dec = ActiveRecordPgStuff::Relation::TemporaryTable::Decorator.new csv_records.klass, name
              rel = ActiveRecord::Relation.new dec, table: dec.arel_table
              rel.readonly!

              rel.connection.execute("insert into #{name}(operation, row_number, name, email, phone_number, assistants, extra) #{deleted_records.to_sql}")
              rel.connection.execute("insert into #{name}(operation, row_number, name, email, phone_number, assistants, extra) #{changed_records.to_sql}")

              if options[:skip_noop] != true
                rel.connection.execute("insert into #{name}(operation, row_number, name, email, phone_number, assistants, extra) #{unchanged_records.to_sql}")
              end

              rel.order(:row_number).each do |operation|
                add_operation(operation)
              end
            end
          end
        end

        prioritize_assistants(operations)
      end

      private

      def add_operation(operation)
        op = [
          operation.operation.to_sym,
          operation.name,
          operation.email,
          operation.phone_number.presence,
          serialize_pg_array(operation.assistants)
        ]
        op << operation.extra unless operation[:extra].nil?
        operations << op
      end

      def serialize_pg_array(pg_array)
        return if pg_array.nil?
        pg_array = pg_array[1...-1] # remove the curly braces
        pg_array.presence
      end

      def prioritize_assistants(operations)
        prioritized_operations = []
        operations.each do |operation|
          process_operation(operation, operations, prioritized_operations, Set.new)
        end
        prioritized_operations
      end

      def process_operation(operation, operations, prioritized_operations, tail)
        (_, _, email, _, assistants) = operation
        return if prioritized_operations.find { |_, _, e| e == email }

        (assistants || '').split(',').each do |assistant_email|
          next if tail.include?(assistant_email)
          assistant_operation = operations.find { |_, _, email| email == assistant_email }
          process_operation(assistant_operation, operations, prioritized_operations, tail.add(email))
        end

        prioritized_operations << operation
      end
    end
  end
end
