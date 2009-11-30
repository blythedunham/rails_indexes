module RailsIndexes
  class IndexingError < StandardError; end

  class IndexerBase
    attr_accessor :migration_options
    def migration
      add = []
      remove = []
      missing_indexes = check_for_indexes
      add_indexes_to_migration!( missing_indexes, add, remove )
      puts create_migration( migration_name, add, remove )
    end

    def self.migration( options = {})
      new( options ).migration
    end

    def initialize(options = {})
      require File.join( File.dirname(__FILE__), 'migration_extensions' )
      options.symbolize_keys
      @migration_options = options || {}
    end

    def self.supports_foreign_keys?
      return @supports_fks if !@supports_fks.nil?
      gem "matthuhiggins-foreigner", :lib => "foreigner", :source => 'http://gemcutter.org'
      require 'foreigner'
      # reload the file incase foreigner was not extended
      load File.dirname(__FILE__) + '/migration_extensions.rb'
      @supports_fks = ActiveRecord::Base.connection.supports_foreign_keys?
    rescue LoadError => e
      @supports_fks = false
    end

    def self.requires_foreign_keys!
      raise RailsIndexes::IndexingError.new(
        "Please install the foreigner gem to use foriegn key attributes"
      ) unless supports_foreign_keys?
    end

    def self.foreign_keys( table_name )
      return [] unless supports_foreign_keys?
      @foreign_keys ||= {}
      @foreign_keys[ table_name.to_s ] ||=
        ActiveRecord::Base.connection.foreign_keys( table_name ) || []
      @foreign_keys[ table_name.to_s ]
    end

    def self.foreign_keys_for_index( index )
      return [] unless supports_foreign_keys?
      foreign_keys( index.tablename ).select do |fk|
        fk.options[:column] == index.columns.first &&
        fk.from_table == index.table
      end
    end

    def self.is_a_fk?( index ); foreign_keys_for_index( index ).any?; end
    
    protected
    def migration_name; 'AddMissingIndexes'; end

    def migration_syntax( code, indent = 4)
      (' ' * indent) + [code].flatten.uniq.join("\n" + (' ' * indent))
    end

    def up_migration( up );     migration_syntax( up );  end
    def down_migration( down ); migration_syntax( down ); end
    def additional_migration_methods; end
    def create_migration( name, up = nil, down=nil, &block )
      return if up.blank? && down.blank?
      migration = <<EOM
class #{name} < ActiveRecord::Migration
  def self.up

    # These indexes were found by searching for AR::Base finds on your application
    # It is strongly recommanded that you will consult a professional DBA about your infrastucture and implemntation before
    # changing your database in that matter.
    # There is a possibility that some of the indexes offered below is not required and can be removed and not added, if you require
    # further assistance with your rails application, database infrastructure or any other problem, visit:
    #
    # http://www.railsmentors.org
    # http://www.railstutor.org
    # http://guides.rubyonrails.org

#{ up_migration( up ) }
  end
  def self.down
#{ down_migration( down ) }
  end
#{additional_migration_methods}
end
EOM
  end
  
    delegate :supports_foreign_keys?, :requires_foreign_keys!, :foreign_keys,
       :is_a_fk?, :foreign_keys_for_index, :to => self

  end
end