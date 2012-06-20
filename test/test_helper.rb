require 'test/unit'
require 'i18n'
require 'i18n/backend/active_record'

require 'armot'
require 'logger'

ActiveRecord::Base.logger = Logger.new(nil)
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

# Allow fallbacks to test production-like behaviour
I18n::Backend::ActiveRecord.send(:include, I18n::Backend::Fallbacks)
I18n.backend = I18n::Backend::ActiveRecord.new

def setup_db
  ActiveRecord::Migration.verbose = false
  load "schema.rb"
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Comment < ActiveRecord::Base
  armotize :msg
end

class Post < ActiveRecord::Base
  armotize :title, :text
  validates_presence_of :title
end

class Product < ActiveRecord::Base
  armotize :name

  def name=(value)
    super(value + " customized")
  end

  def self.find_by_name(value)
    "#{super(value).try(:name)}_override"
  end
end

# Puret translation model to test migration process
class PostTranslation < ActiveRecord::Base
end

def count_query_reads_for(clazz)
  old = ActiveRecord::Base.logger
  log_stream = StringIO.new
  logger = Logger.new(log_stream)
  ActiveRecord::Base.logger = logger
  yield
  ActiveRecord::Base.logger = old
  logger.close
  log_stream.string.scan(/#{clazz} Load/).size
end

def count_query_updates_for(clazz)
  old = ActiveRecord::Base.logger
  log_stream = StringIO.new
  logger = Logger.new(log_stream)
  ActiveRecord::Base.logger = logger
  yield
  ActiveRecord::Base.logger = old
  logger.close
  log_stream.string.scan(/UPDATE \"#{clazz.constantize.table_name}\"/).size
end
