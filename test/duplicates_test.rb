require File.dirname(__FILE__) + '/test_helper'

class DuplicatesTest < ActiveSupport::TestCase

  def detect_duplicates
    @indexer = RailsIndexes::DuplicateDetector.new
    @results = @indexer.send :check_for_indexes
  end

  test "foreign keys has_and_belongs_to_many are created" do
    with_index( :companies, :country_id )
  end

  test "composite column is detected" do
    with_index( :companies, [:country_id, 'id'], :name => 'boo', :compare_with => 0 )
  end

  protected

  def matches_options?( index, options )
    options.all? do |k,v|
       (k.to_s == 'columns' && [v].flatten === [index.columns].flatten) ||
       index.send( k ).to_s == v.to_s
    end
  end
  def duplicates_found( options )
    detect_duplicates unless @results
    candidate_indexes = options.delete( :compare_with ) || [0, 1]
    candiate_indexes = [candidate_indexes].flatten
    table_results = @results[options[:table].to_s] || []
    table_results.select{ |idx|
      candidate_indexes.any? do |i|
        matches_options?( idx[i], options)
      end
    }
  end

  def assert_duplicate( options )
    assert_equal(1, duplicates_found( options ).length, "No duplicates found for #{options.inspect} in #{@results.inspect}")
  end

  def with_index( table, column, options = {} )
    columns = [column].flatten.collect{|c| c.to_s }
    options[:name]||= "index_#{table}_on_#{columns.join('_and_')}_#{rand(5000)}"
    ActiveRecord::Migration.add_index table, columns, options
    if block_given?
      yield options[:name]
    else
      assert_duplicate( :table => table, :columns => columns, :name => options[:name])
    end
  ensure
    ActiveRecord::Migration.remove_index table, :name => options[:name]
  end
end