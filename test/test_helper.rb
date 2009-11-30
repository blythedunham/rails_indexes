
require 'test/unit'
require 'rubygems'
require 'active_support'
require 'active_support/test_case'
require 'active_record'
require 'active_record/test_case'
require 'active_record/connection_adapters/mysql_adapter'
require 'action_controller'

begin
  require 'ruby-debug'
rescue LoadError
  puts "ruby-debug not loaded"
end

connection_params = if ENV['DB']
  { :adapter => ENV['DB'], :database => 'rails_indexes_test' }
else
  { :adapter  => "sqlite3", :database => ":memory:" }
end

ActiveRecord::Base.establish_connection( connection_params )

ActiveRecord::Base.logger = Logger.new("debug.log")

begin
  require 'foreigner'
rescue LoadError
  puts "foreigner not loaded"
end

silence_warnings {
  ROOT       = File.join(File.dirname(__FILE__), '..')
  RAILS_ROOT = ROOT
}

$LOAD_PATH << File.join(ROOT, 'lib')
$LOAD_PATH << File.join(ROOT, 'lib', 'rails_indexes')

require 'indexer'
require 'foreign_key_indexer'
require 'duplicate_detector'

class Rails
  def self.root
    "test/fixtures/"
  end

  def self.logger
    ActiveRecord::Base.logger
  end
end

ENV['RAILS_ENV'] ||= 'test'

load 'test/fixtures/schema.rb'

# Load models
Dir['test/fixtures/app/models/**/*.rb'].each { |f| require f }

# load controllers
Dir['test/fixtures/app/controllers/**/*.rb'].each { |f| require f }
