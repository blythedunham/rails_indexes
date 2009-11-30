require File.join( File.dirname(__FILE__), 'indexer_base' )
module RailsIndexes
  class DuplicateDetector < IndexerBase

    protected
    def migration_name; 'RemoveDuplicateIndexes'; end
    
    def check_for_indexes( table_names = nil )
      table_names ||= ActiveRecord::Base.connection.tables
      table_names.inject({}) do |duplicates_per_table, table_name|
        indexes = ActiveRecord::Base.connection.indexes( table_name )
        #if ForeignKeyIndexer.supports_foreign_keys?
        #  indexes.concat( ActiveRecord::Base.connection.foreign_keys( table_name ) )
        #end
        dups = discover_duplicate_indexes( indexes )
        duplicates_per_table[table_name] = dups unless dups.blank?
        duplicates_per_table
      end
    end

    def add_indexes_to_migration!( dups, up, down )
      total_count = 0
      dups.each do |table_name, keys|
        keys.each do |key_pair|
          add_migration_key_pair!( up,  key_pair, total_count, false )
          add_migration_key_pair!( down,key_pair, total_count, true  )
        end
      end
    end

    def discover_duplicate_indexes(keys)
      duplicates = []
      keys.each_with_index do |key1, i|
        keys.each_with_index do |key2, j|
          next if i == j
          next if duplicates.any?{|x| x.first === key1 || x.first === key2 }
          if is_a_duplicate_index_of?( key1, key2 )
            duplicates.any?{|x| x.first === key1 || x.first === key2 }
          end
          duplicates << [key1, key2] if is_a_duplicate_index_of?( key1, key2 )
        end
      end
      duplicates
    end

    def add_migration_key_pair!( list, key_pair, total_count, add_key )
      list << "# Duplicate #{total_count}"
      list << key_pair.first.to_migration( add_key )
      list << '#' + key_pair.last.to_migration( add_key )
      list << ''
    end


    # return true if the columns of this index are a subset of the other
    def is_a_subset_of?( key1, key2 )
      return false if key1.columns.length > key2.columns.length
      0.upto( key1.columns.length - 1 ) do |i|
        return false if key1.columns[i] != key2.columns[i]
      end
      true
    end

    # Return true if this is a duplicate index of the other
    def is_a_duplicate_index_of?( key1, key2 )
      if is_a_subset_of?( key1, key2 )
        # a is a duplicate if it is not unique
        return true if !key1.unique

        #both are unique and the columns are the same length
        return true if other.unique && key1.columns.length == other.columns.length
      end
      false
    end
  end
end
