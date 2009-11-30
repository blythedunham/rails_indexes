require File.dirname(__FILE__) + '/test_helper'

if RailsIndexes::ForeignKeyIndexer.supports_foreign_keys?
  class ForeignKeysTest < ActiveSupport::TestCase

    def setup
      @indexer = RailsIndexes::ForeignKeyIndexer.new
      @results = @indexer.send :check_for_indexes
    end

    test "foreign keys has_and_belongs_to_many are created" do
      assert_matching_index(
        :from_table => 'companies_freelancers',
        :to_table => 'companies',
        :options => { :primary_key => 'id', :column => 'company_id' }
      )
      assert_matching_index(
        :from_table => 'companies_freelancers',
        :to_table => 'freelancers',
        :options => { :primary_key => 'id', :column => 'freelancer_id' }
      )
    end

    test "foregin keys has_and_belongs_to_many with custom columns" do
      assert_matching_index(
        :from_table => 'purchases',
        :to_table => 'gifts',
        :options => { :primary_key => 'custom_primary_key', :column => 'present_id', :dependent => 'delete' }
      )
      assert_matching_index(
        :from_table => 'purchases',
        :to_table => 'users',
        :options => { :primary_key => 'id', :column => 'buyer_id', :dependent => 'delete' }
      )
    end

    test "belongs_to" do
      assert_matching_index(
        :from_table => 'addresses',
        :to_table => 'countries',
        :options => {
          :column => 'country_id',
          :primary_key => 'id',
          :dependent => :nullify
        }
      )
    end

    test "belongs_to with a custom foreign key" do

      assert_matching_index(
        :from_table => 'companies',
        :to_table => 'users',
        :options => {
          :column => 'owner_id',
          :primary_key => 'id',
          :dependent => :nullify
        }
      )

    end

    test "should not add an already existing index" do
      assert_no_matching_index(
        :from_table => 'companies',
        :options => { :column => 'country_id' }
      )
    end


    test "relationship indexes are found" do
      assert @results.length > 0

      %w(companies companies_freelancers addresses purchases).each do |tablename|
        assert_matching_index( :from_table => tablename)
      end
    end

    protected
    def find_matching_key( options )
      result = @results.detect do |fk|
        options.all? do |key, value|
          if key.to_s == 'options'
            value.all?{|ok, ov| ov.to_s == fk.options[ok.to_sym].to_s }
          else
            fk.send( key ) == value
          end
        end
      end
    end

    def assert_matching_index( options )
      assert( find_matching_key( options ), "No foreign key found with #{options.inspect}  \n#{@results.inspect}")
    end

    def assert_no_matching_index( options )
      key = find_matching_key( options )
      assert_nil( key, "Expecting no foreign key matching #{options.inspect} but found #{key.inspect}")
    end
  end
else
  puts "Skipping foreign key test. Use DB=mysql rake test"
end
