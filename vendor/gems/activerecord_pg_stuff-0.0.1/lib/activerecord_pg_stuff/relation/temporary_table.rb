module ActiveRecordPgStuff
  module Relation

    module TemporaryTable

      class Decorator
        attr_reader :table_name, :arel_table, :quoted_table_name

        def initialize(object, table_name)
          @table_name        = table_name
          @object            = object
          @arel_table        = Arel::Table.new(table_name)
          @quoted_table_name = @object.connection.quote_table_name(table_name)
        end

        def method_missing(name, *args, &block)
          @object.send(name, *args, &block)
        end

        def respond_to?(name, *args)
          @object.respond_to?(name, *args)
        end
      end

      def temporary_table
        tname = "temporary_#{self.table_name}_#{self.object_id}"
        self.klass.connection.with_temporary_table tname, self.to_sql do |name|
          dec     = Decorator.new self.klass, name
          rel     = ActiveRecord::Relation.new dec, dec.arel_table
          rel.readonly!
          yield rel
        end
      end

    end

  end
end
