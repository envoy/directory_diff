# frozen_string_literal: true

require "activerecord_pg_stuff"

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
        current_directory_temp_table do |temp_current_directory|
          new_directory_temp_table(new_directory) do |deduped_csv|
            # Get Arel tables for referencing fields, table names
            employees = temp_current_directory.table
            csv = deduped_csv.table

            # Reusable Arel predicates
            csv_employee_join = csv[:email].eq(employees[:email])
            attributes_unchanged = employees[:name].eq(csv[:name])
                                    .and(
                                      employees[:phone_number].eq(csv[:phone_number])
                                        .or(csv[:phone_number].eq(""))
                                        # ☝🏽 Comparing to an empty string because we cast
                                        # phone number to an empty string. The reason is
                                        # comparing NULL = NULL is always false in SQL
                                    )
                                    .and(
                                      employees[:assistants].contains(csv[:assistants])
                                    )

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

            connection.execute(SQL.cleanup_sql(csv.name))

            csv_fields = [:name, :email, :phone_number, :assistants, :extra]

            # new records are records in the new directory that don't exist in
            # the current directory
            new_records = csv_records
                            .select("'insert'::varchar operation, row_number")
                            .select(csv_fields)
                            .where({ employees.name => { email: nil } })
            # deleted records are records in the current directory that don't
            # exist in the new directory
            deleted_records = employee_records
                                .select("'delete'::varchar operation, row_number")
                                .select(csv_fields)
                                .where({ csv.name => { email: nil } })
            # changed records are records that have difference in name, phone
            # number and/or assistants
            changed_records = csv_records
                                .select("'update'::varchar operation, row_number")
                                .select(csv_fields)
                                .where.not(attributes_unchanged)
            # unchanged records are records that are exactly the same in both
            # directories (without considering the extra field)
            unchanged_records = csv_records
                                  .select("'noop'::varchar operation, row_number")
                                  .select(csv_fields)
                                  .where(attributes_unchanged)

            # create temp table for holding operations
            temp_table(new_records.to_sql) do |operations|
              insert_into_operations(operations, deleted_records.to_sql)
              insert_into_operations(operations, changed_records.to_sql)
              if options[:skip_noop] != true
                insert_into_operations(operations, unchanged_records.to_sql)
              end

              operations.order(:row_number).each do |operation|
                add_operation(operation)
              end
            end
          end
        end

        prioritize_assistants(operations)
      end

      private

      def current_directory_temp_table(&block)
        # outer temp table is required so that the projection does not run into
        # ambiguous column issues
        temp_table(current_directory) do |rel|
          temp_table(rel.select(SQL.current_directory_projection), &block)
        end
      end

      def new_directory_temp_table(source, &block)
        convert_to_relation(source) do |relation|
          relation = relation.select("*")
            .from(Arel.sql("(#{SQL.latest_unique_sql(relation.table.name)}) as t"))
            .order("row_number")

          temp_table(relation, &block)
        end
      end

      def convert_to_relation(source, &block)
        return block.call(source) if source.is_a?(ActiveRecord::Relation)

        temp_table do |relation|
          table_name = relation.table.name
          connection.change_table(table_name) do |t|
            t.column :name, :string
            t.column :email, :string
            t.column :phone_number, :string
            t.column :assistants, :string
            t.column :extra, :string
          end
          insert_into_csv_table(table_name, source)
          block.call(relation)
        end
      end

      # TODO chunk this into batch sizes
      def insert_into_csv_table(table_name, records)
        return if records.empty?

        values = records.map do |row|
          (name, email, phone_number, assistants, extra) = row
          columns = [
            connection.quote(name),
            connection.quote(email),
            connection.quote(phone_number),
            connection.quote(assistants),
            connection.quote(extra)
          ]
          "(#{columns.join(", ")})"
        end

        connection.execute(SQL.insert_into_temp_csv_table(table_name, values))
      end

      def temp_table(source = nil, &block)
        return source.temporary_table(&block) if source.is_a?(ActiveRecord::Relation)

        create_temp_table(source) do |name|
          klass = current_directory.klass
          dec = ActiveRecordPgStuff::Relation::TemporaryTable::Decorator.new(klass, name)
          if activerecord52?
            rel = ActiveRecord::Relation.new(dec)
          else
            rel = ActiveRecord::Relation.new(dec, dec.arel_table, dec.predicate_builder, {})
          end
          rel.readonly!
          block.call(rel)
        end
      end

      def create_temp_table(initial_sql=nil)
        table_name = "temporary_#{(Time.now.to_f * 1000).to_i}"

        if initial_sql
          connection.with_temporary_table(table_name, initial_sql) do |name|
            yield name
          end
        else
          connection.transaction do
            begin
              connection.create_table(table_name, temporary: true)
              yield table_name
            ensure
              connection.drop_table(table_name)
            end
          end
        end
      end

      def insert_into_operations(relation, sql)
        connection.execute(SQL.insert_into_operations(relation.table.name, sql))
      end

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
          process_operation(
            assistant_operation,
            operations,
            prioritized_operations,
            tail.add(email)
          )
        end

        prioritized_operations << operation
      end

      def connection
        current_directory.connection
      end

      def activerecord52?
        ActiveRecord.gem_version >= Gem::Version.new("5.2.x")
      end
    end

    module SQL
      # Cleanup some bad records
      # 1. Assistant email is set on an employee, but no assistant record
      #    in csv. Remove the assistant email.
      # 2. Assistant email is employee's own email. Remove the assistant
      #    email.
      # TODO move this into the temp table creation above
      # https://www.db-fiddle.com/f/gxg6qABP1LygYvvgRvyH2N/1
      def self.cleanup_sql(table_name)
        <<-SQL
          with
            unnested_assistants as
            (
              select
                email,
                name,
                unnest(assistants) assistant
              from #{table_name}
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
              left outer join #{table_name} b on a.assistant = b.email
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
              from #{table_name} a
              left outer join missing_assistants_removed b
              using (email)
              group by
                a.email, a.name
            )
          update #{table_name}
          set assistants = only_valid_assistants.assistants
          from only_valid_assistants
          where #{table_name}.email = only_valid_assistants.email
        SQL
      end

      # Remove dupe email rows, keeping the last one
      def self.latest_unique_sql(table_name)
        <<-SQL
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
            #{table_name}
          ORDER BY
            lower(email),
            row_number desc
        SQL
      end

      def self.current_directory_projection
        <<-SQL
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
      end

      def self.insert_into_operations(table_name, sql)
        <<-SQL
          insert into #{table_name}(
            operation,
            row_number,
            name,
            email,
            phone_number,
            assistants,
            extra
          ) #{sql}
        SQL
      end

      def self.insert_into_temp_csv_table(table_name, values)
        <<-SQL
          insert into #{table_name}(
            name,
            email,
            phone_number,
            assistants,
            extra
          ) values #{values.join(", ")}
        SQL
      end
    end
  end
end
