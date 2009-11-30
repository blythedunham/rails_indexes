
# Not sure about postgre and other adapters
ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
  def enable_foreign_keys_sql
    return unless supports_foreign_keys?
    "set foreign_key_checks = 1;"
  end

  def disable_foreign_keys_sql
    return unless supports_foreign_keys?
    "set foreign_key_checks = 0;"
  end
end

ActiveRecord::ConnectionAdapters::IndexDefinition.class_eval do
 #include RailsIndexes::MigrationExtensions
 
 def to_migration( is_up = true )
   statment_parts = [(is_up ? 'add_index ' : 'remove_index ') + self.table.inspect]
   statment_parts << self.columns.inspect if is_up
   statment_parts << (':name => ' + self.name.inspect) if self.name
   statment_parts << ':unique => true' if unique
   statment_parts.join(', ')
 end
end

if defined?( Foreigner ) and defined?( Foreigner::ConnectionAdapters::ForeignKeyDefinition )
  Foreigner::ConnectionAdapters::ForeignKeyDefinition.class_eval do
    #include RailsIndexes::MigrationExtensions

    def initialize(*args)
      super(*args)
      self.options[:name]||= foreign_key_name
    end

    def foreign_key_name
      ActiveRecord::Base.connection.send(
        :foreign_key_name, from_table, options[:column], options
      ) if from_table && options[:column]
    end

    def to_migration( is_up = true )
      statement_parts = [ (is_up ? 'add_foreign_key ' : 'remove_foreign_key ') ]
      statement_parts.first << from_table.inspect
      statement_parts << to_table.inspect if is_up
      
      statement_parts << (':name => ' + options[:name].inspect) if options[:name]

      if options[:column] != "#{to_table.singularize}_id"
        statement_parts << (':column => ' + options[:column].inspect)
      end
      if options[:primary_key] != 'id'
        statement_parts << (':primary_key => ' + options[:primary_key].inspect)
      end
      if options[:dependent].present?
        statement_parts << (':dependent => ' + options[:dependent].inspect)
      end

      statement_parts.join(', ')
    end
  end
end
