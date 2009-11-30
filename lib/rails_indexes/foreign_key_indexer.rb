require File.join( File.dirname(__FILE__), 'indexer_base' )

module RailsIndexes
  class ForeignKeyIndexer < IndexerBase

    def dependent_value_assignment
      migration_options[:dependent_value_assignment]||= :aggressive
    end

    protected
    def migration_name; 'AddMissingForeignKeys'; end
    def check_for_indexes
      requires_foreign_keys!
      foreign_keys = []
      Indexer.check_for_indexes do |reflection|
        reflection_to_foreign_keys!( reflection, foreign_keys )
      end
      foreign_keys
    end

    def migration_foreign_key_block( indent = 2)
     space = ' ' * indent
<<-END_CODE
#{space}def self.disable_foreign_keys
#{space}  execute "#{ActiveRecord::Base.connection.disable_foreign_keys_sql}"
#{space}  yield
#{space}ensure
#{space}  execute "#{ActiveRecord::Base.connection.enable_foreign_keys_sql}"
#{space}end
END_CODE
    end
    def migration_syntax_with_disable( list, indent = 2 )
      space = ' ' * indent
<<-END_M
#{space}disable_foreign_keys do
#{migration_syntax( list, indent + 2)}
#{space}end
END_M
    end

    def up_migration(up);             migration_syntax_with_disable(up, 4);   end
    def down_migration(down);         migration_syntax_with_disable(down, 4); end
    def additional_migration_methods; migration_foreign_key_block; end

    def reflection_to_foreign_keys( reflection )
      foreign_keys = []
      case reflection.macro
        when :belongs_to
          
          unless reflection.options[:polymorphic]
            foreign_keys << Foreigner::ConnectionAdapters::ForeignKeyDefinition.new(
              reflection.active_record.table_name,
              reflection.table_name,
              :dependent => dependent_value( reflection, 'nullify'),
              :column => reflection.primary_key_name,
              :primary_key => reflection.klass.primary_key
            )
          end
        when :has_and_belongs_to_many
          from_table_name = reflection.options[:join_table]
          foreign_keys << Foreigner::ConnectionAdapters::ForeignKeyDefinition.new(
            from_table_name,
            reflection.active_record.table_name,
            :column => reflection.primary_key_name,
            :primary_key => reflection.active_record.primary_key,
            :dependent => dependent_value( reflection, 'delete' )
          )

          foreign_keys << Foreigner::ConnectionAdapters::ForeignKeyDefinition.new(
            from_table_name,
            reflection.table_name,
            :column => reflection.association_foreign_key,
            :primary_key => reflection.klass.primary_key,
            :dependent => dependent_value( reflection, 'delete' )
          )
      end
      foreign_keys
    end

    # add foreign keys based on the reflection information
    def reflection_to_foreign_keys!( reflection, foreign_key_list )
      reflection_to_foreign_keys( reflection ).each do |foreign_key|
        #skip if already in this list or the fk has already been uped in the db
        next if includes_foreign_key?( foreign_key, foreign_key_list ) ||
                existing_foreign_key?( foreign_key )
        foreign_key_list << foreign_key
      end
    end

    # returns true if the foreign key is already in the list
    # list defaults to the existing foreign keys
    def includes_foreign_key?( key, list = nil )
      list  ||= foreign_keys( key.from_table )
      list.any?{|fk| matching_foreign_keys( key, fk) }
    end
    alias_method :existing_foreign_key?, :includes_foreign_key?

    def matching_foreign_keys( key1, key2 )
      key1.options[:primary_key] == key2.options[:primary_key] &&
      key1.options[:column]      == key2.options[:column] &&
      key1.from_table            == key2.from_table &&
      key1.to_table              == key2.to_table
    end

    def add_indexes_to_migration!( foreign_keys, up, down )
      foreign_keys.each do |key|
        up    << key.to_migration( true )
        down  << key.to_migration( false )
      end
    end

    def assign_dependent_value( reflection )
      if dependent_value_assignment == :aggressive
        column = reflection.active_record.columns_hash[ reflection.primary_key_name ]
        return(column.null ? :nullify : :delete) if column
      end
      nil
    end

    def dependent_value( reflection, default_type = nil )
      case (reflection.options[:dependent]).to_s
        when 'destroy'  then nil
        when /delete/   then :delete
        when 'nullify'  then :nullify
        else assign_dependent_value( reflection ) || default_type
      end
    end
  end
end
